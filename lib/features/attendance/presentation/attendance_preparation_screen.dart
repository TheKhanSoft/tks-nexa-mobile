import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_hardware_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/face_capture_screen.dart';

class AttendancePreparationScreen extends ConsumerStatefulWidget {
  const AttendancePreparationScreen({super.key});

  @override
  ConsumerState<AttendancePreparationScreen> createState() =>
      _AttendancePreparationScreenState();
}

class _AttendancePreparationScreenState
    extends ConsumerState<AttendancePreparationScreen> {
  static const _maximumLocationAge = Duration(seconds: 30);
  static const _maximumLocationAccuracyM = 50.0;

  LocationEvidence? _location;
  FaceCaptureEvidence? _faceCapture;
  String? _locationError;
  bool _capturingLocation = false;

  @override
  void initState() {
    super.initState();
    // Automatically trigger fresh GPS location capture on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _location == null && !_capturingLocation) {
        _captureLocation();
      }
    });
  }

  bool _locationReady(double maximumAccuracyM) {
    final location = _location;
    return location != null &&
        location.isFreshAt(
          DateTime.now().toUtc(),
          maximumAge: _maximumLocationAge,
        ) &&
        location.meetsAccuracy(maximumAccuracyM);
  }

  double get _requiredLocationAccuracyM =>
      ref.read(attendanceChallengeProvider).value?.location?.minimumAccuracyM ??
      _maximumLocationAccuracyM;

  Future<void> _captureLocation() async {
    if (_capturingLocation) return;
    setState(() {
      _capturingLocation = true;
      _locationError = null;
    });
    try {
      final evidence = await ref
          .read(locationCaptureServiceProvider)
          .captureFresh();
      if (!mounted) return;
      setState(() {
        _location = evidence;
        if (!evidence.meetsAccuracy(_requiredLocationAccuracyM)) {
          _locationError =
              'Accuracy is ${evidence.horizontalAccuracyM.toStringAsFixed(0)} m. Move into an open area and retry.';
        }
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _locationError =
              'A fresh location could not be obtained. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _captureFace() async {
    // Automatically refresh location if missing or stale (>30s old) before photo capture
    final now = DateTime.now().toUtc();
    if (_location == null ||
        !_location!.isFreshAt(now, maximumAge: _maximumLocationAge)) {
      await _captureLocation();
      if (!mounted) return;
    }

    final capture = await Navigator.of(context).push<FaceCaptureEvidence>(
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
    );
    if (!mounted || capture == null) return;
    _discardFaceCapture(_faceCapture);
    setState(() => _faceCapture = capture);
  }

  void _removeFaceCapture() {
    _discardFaceCapture(_faceCapture);
    setState(() => _faceCapture = null);
  }

  Future<void> _captureAndUploadPhoto() async {
    final capture = await Navigator.of(context).push<FaceCaptureEvidence>(
      MaterialPageRoute(
        builder: (_) => const FaceCaptureScreen(
          title: 'Enroll Profile Photo',
          instruction: 'Center your face clearly in frame',
        ),
      ),
    );
    if (!mounted || capture == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Uploading photo & enrolling face…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final photoUrl = await ref
          .read(photoUploadControllerProvider.notifier)
          .uploadPhoto(photoBytes: capture.bytes);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        ref.invalidate(faceBiometricProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded and face profile enrolled!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is AppFailure ? e.message : 'Photo upload failed.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitAttendance() async {
    final now = DateTime.now().toUtc();
    if (_location == null ||
        !_location!.isFreshAt(now, maximumAge: _maximumLocationAge)) {
      await _captureLocation();
    }

    final location = _location;
    final capture = _faceCapture;
    if (location == null ||
        capture == null ||
        !_locationReady(_requiredLocationAccuracyM)) {
      return;
    }
    final result = await ref
        .read(attendanceSubmissionProvider.notifier)
        .submit(capture: capture, location: location);
    if (!mounted || result == null) return;
    _discardFaceCapture(_faceCapture);
    setState(() => _faceCapture = null);
    final cameraResult = result.cameraCorroboration;
    if (cameraResult != null &&
        (cameraResult.status == CameraCorroborationStatus.challengeRequired ||
            cameraResult.status ==
                CameraCorroborationStatus.waitingForCamera)) {
      context.push(AppRoutes.cameraVerification, extra: cameraResult);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: AppPalette.emerald),
        title: const Text('Attendance Recorded'),
        content: Text(
          result.trustScore == null
              ? result.message
              : '${result.message}\n\nTrust: ${result.trustScore}/100 (${result.trustLevel ?? 'assessed'})',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _discardFaceCapture(_faceCapture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faceCapture = _faceCapture;
    final biometricProfile = ref.watch(faceBiometricProfileProvider);
    final challenge = ref.watch(attendanceChallengeProvider);
    final submission = ref.watch(attendanceSubmissionProvider);
    final submissionError = submission.hasError
        ? switch (submission.error) {
            AppFailure failure => failure.message,
            _ => 'Attendance could not be recorded. Please try again.',
          }
        : null;
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final requiredAccuracy =
        challenge.value?.location?.minimumAccuracyM ??
        _maximumLocationAccuracyM;
    final locationReady = _locationReady(requiredAccuracy);
    final insecureLanBrowser =
        kIsWeb &&
        Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: brand.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                SizedBox(height: 18),
                Text(
                  'Verify Your Presence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Location is automatically captured for this attempt. Face verification evidence and phone hardware telemetry are sent securely.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (insecureLanBrowser) ...[
            const _BrowserSecurityNotice(),
            const SizedBox(height: 14),
          ],
          _ChallengeReadinessCard(
            challenge: challenge,
            onRetry: () => ref.invalidate(attendanceChallengeProvider),
          ),
          const SizedBox(height: 14),
          _BiometricReadinessCard(
            profile: biometricProfile,
            onRetry: () => ref.invalidate(faceBiometricProfileProvider),
            onUploadPhoto: _captureAndUploadPhoto,
          ),
          const SizedBox(height: 14),
          _EvidenceCard(
            step: '1',
            icon: Icons.my_location_rounded,
            title: 'Fresh Location',
            subtitle: _locationDescription(),
            ready: locationReady,
            error: _locationError,
            action: FilledButton.icon(
              key: const Key('capture_location'),
              onPressed: _capturingLocation ? null : _captureLocation,
              icon: _capturingLocation
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
              label: Text(
                _location == null ? 'Acquiring GPS…' : 'Refresh Location',
              ),
            ),
          ),
          const SizedBox(height: 14),
          _EvidenceCard(
            step: '2',
            icon: Icons.face_retouching_natural_rounded,
            title: 'Face Photo',
            subtitle: faceCapture == null
                ? 'Align face inside frame for on-device verification.'
                : 'Captured at ${_formatTime(faceCapture.capturedAt)} · ${(faceCapture.bytes.length / 1024).round()} KB',
            ready: faceCapture != null,
            preview: faceCapture == null
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      faceCapture.bytes,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
            action: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('open_face_camera'),
                    onPressed: _captureFace,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(faceCapture == null ? 'Open Camera' : 'Retake'),
                  ),
                ),
                if (faceCapture != null) ...[
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Remove photo',
                    onPressed: _removeFaceCapture,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brand.softAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Location, face evidence, and mobile hardware details are sent to the central server. The server automatically determines Check-in / Check-out status based on your shift.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('continue_attendance'),
            onPressed:
                locationReady &&
                    faceCapture != null &&
                    challenge.hasValue &&
                    biometricProfile.hasValue &&
                    !submission.isLoading
                ? _submitAttendance
                : null,
            icon: submission.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint_rounded),
            label: Text(
              submission.isLoading
                  ? 'Verifying securely…'
                  : 'Verify & Mark Attendance',
            ),
          ),
          if (submissionError != null) ...[
            const SizedBox(height: 12),
            Text(
              submissionError,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (submission.error is AppFailure &&
                (submission.error as AppFailure).diagnosticCode ==
                    'PASSWORD_CHANGE_REQUIRED') ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.changePassword),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Change Password Now'),
              ),
            ] else if (submission.error is AppFailure &&
                ((submission.error as AppFailure).diagnosticCode ==
                        'PHOTO_REQUIRED' ||
                    (submission.error as AppFailure).diagnosticCode ==
                        'FACE_NOT_ENROLLED')) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _captureAndUploadPhoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Upload Profile Photo Now'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _locationDescription() {
    final location = _location;
    if (location == null) {
      return 'Automatically acquiring fresh GPS coordinates…';
    }
    final mockNote = location.isMocked
        ? ' · device reported mock telemetry'
        : '';
    return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)} · ±${location.horizontalAccuracyM.toStringAsFixed(0)} m$mockNote';
  }
}

class _BrowserSecurityNotice extends StatelessWidget {
  const _BrowserSecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const ListTile(
        leading: Icon(Icons.lock_outline_rounded),
        title: Text(
          'HTTPS is required for mobile-browser camera and GPS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'This LAN page uses HTTP. Android browsers may block camera and precise location. Use the installed app, or serve both the app and APIs through trusted HTTPS.',
        ),
      ),
    );
  }
}

class _ChallengeReadinessCard extends StatelessWidget {
  const _ChallengeReadinessCard({
    required this.challenge,
    required this.onRetry,
  });

  final AsyncValue<AttendanceChallenge> challenge;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: switch (challenge) {
        AsyncData(:final value) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.policy_rounded)),
          title: Text(
            value.location?.name ?? 'Attendance Policy Ready',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'GPS accuracy: ±${value.location?.minimumAccuracyM.toStringAsFixed(0) ?? '50'} m'
            '${value.policy.polygonGeofenceEnabled ? ' · Polygon geofence' : ''}'
            '${value.policy.cameraVerificationEnabled ? ' · Camera corroboration' : ''}',
          ),
          trailing: const Icon(
            Icons.verified_rounded,
            color: AppPalette.emerald,
          ),
        ),
        AsyncError(:final error) => ListTile(
          leading: Icon(
            Icons.policy_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text(
            'Attendance Policy Unavailable',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            error is AppFailure
                ? error.message
                : 'A secure attendance challenge could not be created.',
          ),
          trailing: IconButton(
            tooltip: 'Retry challenge',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        _ => const ListTile(
          leading: CircleAvatar(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(
            'Preparing Secure Attendance',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Loading location and verification policy…'),
        ),
      },
    );
  }
}

class _BiometricReadinessCard extends StatelessWidget {
  const _BiometricReadinessCard({
    required this.profile,
    required this.onRetry,
    required this.onUploadPhoto,
  });

  final AsyncValue<FaceBiometricProfile> profile;
  final VoidCallback onRetry;
  final VoidCallback onUploadPhoto;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final (icon, title, subtitle, color) = switch (profile) {
      AsyncData() => (
        Icons.verified_user_rounded,
        'Face Profile Ready',
        'Protected 512-value biometric profile active.',
        AppPalette.emerald,
      ),
      AsyncError(:final error) => (
        Icons.face_retouching_off_rounded,
        'Face Profile Unavailable',
        error is AppFailure
            ? error.message
            : 'The face profile could not be loaded.',
        Theme.of(context).colorScheme.error,
      ),
      _ => (
        Icons.downloading_rounded,
        'Loading Face Profile',
        'Checking the protected employee biometric profile…',
        Theme.of(context).colorScheme.primary,
      ),
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color.alphaBlend(
            color.withValues(alpha: .13),
            brand.softAccent,
          ),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: profile.hasError
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Retry enrollment profile',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: onUploadPhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Upload Photo'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ready,
    required this.action,
    this.error,
    this.preview,
  });

  final String step;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool ready;
  final String? error;
  final Widget? preview;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ready
                        ? AppPalette.emerald.withValues(alpha: .11)
                        : brand.softAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    ready ? Icons.check_rounded : icon,
                    color: ready
                        ? AppPalette.emerald
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP $step',
                        style: TextStyle(
                          color: brand.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: TextStyle(color: brand.mutedText, height: 1.4),
            ),
            if (error case final message?) ...[
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (preview case final child?) ...[
              const SizedBox(height: 14),
              child,
            ],
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

void _discardFaceCapture(FaceCaptureEvidence? capture) {
  if (capture == null) return;
  PaintingBinding.instance.imageCache.evict(MemoryImage(capture.bytes));
  capture.clear();
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_hardware_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
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
  static const _maximumLocationAge = Duration(seconds: 15);
  static const _maximumLocationAccuracyM = 50.0;

  LocationEvidence? _location;
  FaceCaptureEvidence? _faceCapture;
  String? _locationError;
  bool _capturingLocation = false;
  AttendanceType _attendanceType = AttendanceType.checkIn;

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

  Future<void> _submitAttendance() async {
    final location = _location;
    final capture = _faceCapture;
    if (location == null ||
        capture == null ||
        !_locationReady(_requiredLocationAccuracyM)) {
      return;
    }
    final result = await ref
        .read(attendanceSubmissionProvider.notifier)
        .submit(capture: capture, location: location, type: _attendanceType);
    if (!mounted || result == null) return;
    _discardFaceCapture(_faceCapture);
    setState(() => _faceCapture = null);
    final cameraResult = result.cameraCorroboration;
    if (cameraResult != null &&
        (cameraResult.status ==
                CameraCorroborationStatus.challengeRequired ||
            cameraResult.status ==
                CameraCorroborationStatus.waitingForCamera)) {
      context.push(AppRoutes.cameraVerification, extra: cameraResult);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: AppPalette.emerald),
        title: const Text('Attendance recorded'),
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
          'Secure attendance',
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
                  'Verify your presence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Location is captured only for this attempt. The face image is temporary and must be verified by the server before attendance can be recorded.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (insecureLanBrowser) ...[
            _BrowserSecurityNotice(),
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
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance action',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AttendanceType>(
                      segments: const [
                        ButtonSegment(
                          value: AttendanceType.checkIn,
                          icon: Icon(Icons.login_rounded),
                          label: Text('Check in'),
                        ),
                        ButtonSegment(
                          value: AttendanceType.checkOut,
                          icon: Icon(Icons.logout_rounded),
                          label: Text('Check out'),
                        ),
                      ],
                      selected: {_attendanceType},
                      onSelectionChanged: submission.isLoading
                          ? null
                          : (selection) => setState(
                              () => _attendanceType = selection.single,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _EvidenceCard(
            step: '1',
            icon: Icons.my_location_rounded,
            title: 'Fresh location',
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
                _location == null ? 'Get current location' : 'Refresh location',
              ),
            ),
          ),
          const SizedBox(height: 14),
          _EvidenceCard(
            step: '2',
            icon: Icons.face_retouching_natural_rounded,
            title: 'Temporary face capture',
            subtitle: faceCapture == null
                ? 'Use the front camera for server-side face and liveness verification.'
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
                    label: Text(faceCapture == null ? 'Open camera' : 'Retake'),
                  ),
                ),
                if (faceCapture != null) ...[
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Remove face capture',
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
                    'The app sends evidence—not a client-side “verified” decision. Laravel remains authoritative for location, identity, schedule, duplicates, and attendance time.',
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
                  : 'Verify & mark attendance',
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
          ],
        ],
      ),
    );
  }

  String _locationDescription() {
    final location = _location;
    if (location == null) {
      return 'Capture a new high-accuracy position for this attempt only.';
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
          leading: const CircleAvatar(
            child: Icon(Icons.policy_rounded),
          ),
          title: Text(
            value.location?.name ?? 'Attendance policy ready',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'GPS accuracy: ±${value.location?.minimumAccuracyM.toStringAsFixed(0) ?? '50'} m'
            '${value.policy.polygonGeofenceEnabled ? ' · Polygon geofence' : ''}'
            '${value.policy.cameraVerificationEnabled ? ' · Camera corroboration' : ''}',
          ),
          trailing: const Icon(Icons.verified_rounded, color: AppPalette.emerald),
        ),
        AsyncError(:final error) => ListTile(
          leading: Icon(
            Icons.policy_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text(
            'Attendance policy unavailable',
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
          leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
          title: Text(
            'Preparing secure attendance',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Loading location and verification policy…'),
        ),
      },
    );
  }
}

class _BiometricReadinessCard extends StatelessWidget {
  const _BiometricReadinessCard({required this.profile, required this.onRetry});

  final AsyncValue<FaceBiometricProfile> profile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final (icon, title, subtitle, color) = switch (profile) {
      AsyncData() => (
        Icons.verified_user_rounded,
        'Face enrollment ready',
        'The encrypted 512-value reference profile is available.',
        AppPalette.emerald,
      ),
      AsyncError(:final error) => (
        Icons.face_retouching_off_rounded,
        'Face enrollment unavailable',
        error is AppFailure
            ? error.message
            : 'The face profile could not be loaded.',
        Theme.of(context).colorScheme.error,
      ),
      _ => (
        Icons.downloading_rounded,
        'Loading face enrollment',
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
            ? IconButton(
                tooltip: 'Retry enrollment profile',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
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

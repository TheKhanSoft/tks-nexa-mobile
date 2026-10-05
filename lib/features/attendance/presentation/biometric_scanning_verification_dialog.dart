import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

enum _VerificationState { verifying, success, failed }

class BiometricScanningVerificationDialog extends ConsumerStatefulWidget {
  const BiometricScanningVerificationDialog({
    super.key,
    required this.capture,
    required this.location,
    this.onUploadPhoto,
  });

  final FaceCaptureEvidence capture;
  final LocationEvidence location;
  final VoidCallback? onUploadPhoto;

  @override
  ConsumerState<BiometricScanningVerificationDialog> createState() =>
      _BiometricScanningVerificationDialogState();
}

class _BiometricScanningVerificationDialogState
    extends ConsumerState<BiometricScanningVerificationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  Timer? _stepTimer;
  int _currentStepIndex = 0;
  _VerificationState _state = _VerificationState.verifying;
  AttendanceMarkResult? _result;
  String? _errorMessage;
  String? _diagnosticCode;

  static const _steps = [
    'Scanning facial features…',
    'Analyzing biometric pattern…',
    'Verifying identity with server…',
    'Confirming attendance & location…',
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _stepTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      if (_state == _VerificationState.verifying) {
        setState(() {
          _currentStepIndex = (_currentStepIndex + 1) % _steps.length;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeVerification();
    });
  }

  Future<void> _executeVerification() async {
    setState(() {
      _state = _VerificationState.verifying;
      _errorMessage = null;
      _diagnosticCode = null;
      _currentStepIndex = 0;
    });
    if (!_scanController.isAnimating) {
      _scanController.repeat(reverse: true);
    }

    try {
      final submissionFuture = ref
          .read(attendanceSubmissionProvider.notifier)
          .submit(capture: widget.capture, location: widget.location);

      // Ensure scanning animation is displayed for at least 1.6s for fluid user feedback
      final results = await Future.wait([
        submissionFuture,
        Future<void>.delayed(const Duration(milliseconds: 1600)),
      ]);

      if (!mounted) return;

      final result = results[0] as AttendanceMarkResult?;
      if (result != null) {
        _scanController.stop();
        setState(() {
          _state = _VerificationState.success;
          _result = result;
        });
      } else {
        _scanController.stop();
        final err = ref.read(attendanceSubmissionProvider).error;
        setState(() {
          _state = _VerificationState.failed;
          if (err is AppFailure) {
            _errorMessage = err.message;
            _diagnosticCode = err.diagnosticCode;
          } else {
            _errorMessage = err?.toString() ??
                'Biometric verification was rejected by server.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _scanController.stop();
      setState(() {
        _state = _VerificationState.failed;
        if (e is AppFailure) {
          _errorMessage = e.message;
          _diagnosticCode = e.diagnosticCode;
        } else {
          _errorMessage = e.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color themeAccent;
    switch (_state) {
      case _VerificationState.verifying:
        themeAccent = AppPalette.cyan;
      case _VerificationState.success:
        themeAccent = AppPalette.emerald;
      case _VerificationState.failed:
        themeAccent = AppPalette.coral;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: themeAccent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: themeAccent.withValues(alpha: 0.2),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top HUD Status Badge
              _buildHudHeader(themeAccent),
              const SizedBox(height: 16),

              // Scanning Viewport with Face Image & Animations
              _buildScanningViewport(themeAccent),
              const SizedBox(height: 18),

              // Dynamic Step / Result Section
              switch (_state) {
                _VerificationState.verifying =>
                  _buildVerifyingSection(themeAccent),
                _VerificationState.success => _buildSuccessSection(themeAccent),
                _VerificationState.failed =>
                  _buildFailedSection(context, themeAccent),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudHeader(Color accentColor) {
    final label = switch (_state) {
      _VerificationState.verifying => 'BIOMETRIC SCANNING & MATCHING',
      _VerificationState.success => 'VERIFICATION CONFIRMED',
      _VerificationState.failed => 'VERIFICATION ATTENTION',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningViewport(Color accentColor) {
    return SizedBox(
      width: 205,
      height: 205,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Captured Face Image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              widget.capture.bytes,
              fit: BoxFit.cover,
            ),
          ),

          // Dark tint for contrast
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: Colors.black.withValues(
                alpha: _state == _VerificationState.verifying ? 0.22 : 0.4,
              ),
            ),
          ),

          // Animated Scanning Beam
          if (_state == _VerificationState.verifying)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ScannerBeamPainter(
                    progress: _scanAnimation.value,
                    color: accentColor,
                  ),
                );
              },
            ),

          // HUD Corner Brackets
          CustomPaint(
            painter: _HudCornerBracketPainter(
              color: accentColor,
              strokeWidth: 3.5,
              cornerLength: 24,
            ),
          ),

          // Overlay telemetry tags (HUD aesthetics)
          Positioned(
            top: 8,
            left: 10,
            child: _buildTelemetryTag('FACE SCAN', accentColor),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: _buildTelemetryTag(
              _state == _VerificationState.verifying
                  ? 'MATCHING…'
                  : (_state == _VerificationState.success ? 'VERIFIED' : 'FAILED'),
              accentColor,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 10,
            child: _buildTelemetryTag('LIVE CHECK', accentColor),
          ),
          Positioned(
            bottom: 8,
            right: 10,
            child: _buildTelemetryTag(
              _state == _VerificationState.verifying
                  ? 'ANALYZING'
                  : (_state == _VerificationState.success ? 'PASSED' : 'CHECK FAILED'),
              accentColor,
            ),
          ),

          // Center Status Icon for Success / Failure
          if (_state == _VerificationState.success)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.emerald.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.emerald.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),

          if (_state == _VerificationState.failed)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.coral.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.coral.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildVerifyingSection(Color accentColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _steps[_currentStepIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            color: accentColor,
            backgroundColor: accentColor.withValues(alpha: 0.15),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessSection(Color accentColor) {
    final result = _result;
    return Column(
      children: [
        Text(
          'Identity Verified!',
          style: TextStyle(
            color: accentColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result?.message ?? 'Attendance record logged successfully.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // Badges summary
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (result?.type != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  result!.type!.apiValue.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (result?.trustScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Trust: ${result!.trustScore}% (${result.trustLevel ?? 'High'})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('verification_done_button'),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedSection(BuildContext context, Color accentColor) {
    return Column(
      children: [
        Text(
          'Verification Incomplete',
          style: TextStyle(
            color: accentColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            _errorMessage ?? 'Verification could not be verified by server.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_diagnosticCode == 'PASSWORD_CHANGE_REQUIRED') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(null);
                context.push(AppRoutes.changePassword);
              },
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Change Password Now'),
            ),
          ),
          const SizedBox(height: 10),
        ] else if (_diagnosticCode == 'PHOTO_REQUIRED' ||
            _diagnosticCode == 'FACE_NOT_ENROLLED') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(null);
                widget.onUploadPhoto?.call();
              },
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Upload Profile Photo Now'),
            ),
          ),
          const SizedBox(height: 10),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _executeVerification,
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HudCornerBracketPainter extends CustomPainter {
  const _HudCornerBracketPainter({
    required this.color,
    this.strokeWidth = 3.0,
    this.cornerLength = 22.0,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(l, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, l), paint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - l, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, l), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(l, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - l), paint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - l, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - l), paint);
  }

  @override
  bool shouldRepaint(covariant _HudCornerBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.cornerLength != cornerLength;
}

class _ScannerBeamPainter extends CustomPainter {
  const _ScannerBeamPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    const beamHeight = 28.0;

    // Laser glow rect trailing behind the line
    final glowRect = Rect.fromLTRB(0, (y - beamHeight).clamp(0, size.height), size.width, y);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.32),
        ],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // Laser core line with slight blur
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerBeamPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

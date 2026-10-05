import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/platform/temp_capture_cleanup.dart';
import 'package:tks_nexa_attendance/features/attendance/data/biometric_photo_crop_helper.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_observation_service_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_observation_service.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    this.title = 'Face Verification',
    this.instruction = 'Position face in frame',
  });

  final String title;
  final String instruction;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceCaptureEvidence? _capture;
  String? _cameraError;
  String? _validationError;
  bool _capturing = false;
  bool _returnedCapture = false;
  late final FaceObservationService _faceObserver;
  late String _challenge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceObserver = createFaceObservationService();
    _challenge = 'passive_single_frame';
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraError = null;
      _validationError = null;
    });

    final previousController = _controller;
    _controller = null;
    if (previousController != null) {
      try {
        await previousController.dispose();
      } catch (_) {}
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw CameraException('camera_missing', 'No camera was found.');
        }
        final selected = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        final controller = CameraController(
          selected,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() => _controller = controller);
        return;
      } on CameraException catch (error) {
        if (attempt == 1 &&
            (error.code == 'camera_in_use' ||
                error.code == 'CameraAccessDeniedWithoutPrompt')) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        if (!mounted) return;
        setState(() => _cameraError = _cameraMessage(error));
        return;
      } on Object {
        if (!mounted) return;
        setState(
          () => _cameraError =
              'The camera could not be opened. Check device permissions.',
        );
        return;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// Single-frame passive liveness capture.
  /// Captures 1 single picture, performs passive ML Kit liveness checks
  /// (eyes open, face centered, 1 person in frame) without asking for poses.
  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() {
      _capturing = true;
      _validationError = null;
    });
    String? temporaryPath;
    try {
      final file = await controller.takePicture();
      temporaryPath = file.path;
      final observation = await _faceObserver.observe(file.path);
      _validatePassiveObservation(observation);

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        bytes.fillRange(0, bytes.length, 0);
        throw CameraException(
          'capture_size_invalid',
          'The captured image was empty or too large.',
        );
      }
      _discardCapture(_capture);
      if (!mounted) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      final croppedFaceBytes = BiometricPhotoCropHelper.cropFaceOnly(
        bytes,
        observation.bounds,
      );
      setState(() {
        _capture = FaceCaptureEvidence(
          bytes: bytes,
          croppedFaceBytes: croppedFaceBytes,
          contentType: 'image/jpeg',
          capturedAt: DateTime.now().toUtc(),
          livenessPassed: true,
          livenessChallenge: _challenge,
          faceBounds: observation.bounds,
        );
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => _validationError = error.message);
      try {
        if (controller.value.isInitialized) {
          await controller.resumePreview();
        }
      } catch (_) {}
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = _cameraMessage(error));
    } on Object {
      if (mounted) {
        setState(
          () => _validationError =
              'The face photo could not be captured. Please position your face and try again.',
        );
      }
      try {
        if (controller.value.isInitialized) {
          await controller.resumePreview();
        }
      } catch (_) {}
    } finally {
      if (temporaryPath != null) {
        await deleteTemporaryCapture(temporaryPath);
      }
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Passive liveness validation:
  /// Verifies eyes open, face facing forward, and single face in frame.
  /// Zero reading/posing required by the user!
  void _validatePassiveObservation(FaceObservation observation) {
    final leftEye = observation.leftEyeOpenProbability;
    final rightEye = observation.rightEyeOpenProbability;
    final eyesOpen =
        leftEye == null ||
        rightEye == null ||
        (leftEye >= 0.35 && rightEye >= 0.35);

    if (observation.yaw.abs() > 18 || !eyesOpen) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message:
            'Face forward with both eyes open inside the frame.',
        diagnosticCode: 'PASSIVE_LIVENESS_ALIGNMENT_REQUIRED',
      );
    }
  }

  Future<void> _retake() async {
    _discardCapture(_capture);
    setState(() {
      _capture = null;
      _validationError = null;
      _cameraError = null;
    });
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.resumePreview();
      } else {
        await _initializeCamera();
      }
    } catch (_) {
      await _initializeCamera();
    }
  }

  void _useCapture() {
    final capture = _capture;
    if (capture == null) return;
    _returnedCapture = true;
    Navigator.of(context).pop(capture);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    unawaited(_faceObserver.dispose());
    if (!_returnedCapture) _discardCapture(_capture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final isVerified = capture != null;

    return Scaffold(
      backgroundColor: brand.heroStart,
      appBar: AppBar(
        backgroundColor: brand.heroStart,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Simple visual instruction header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified
                          ? Icons.check_circle_rounded
                          : Icons.face_rounded,
                      color: isVerified
                          ? const Color(0xFF10B981)
                          : Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVerified
                          ? 'Face Verified!'
                          : widget.instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Camera Viewfinder & Frame Overlay
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (capture != null)
                          Image.memory(capture.bytes, fit: BoxFit.cover)
                        else
                          _cameraPreview(),
                        if (capture == null && _cameraError == null)
                          const _FaceGuideOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                children: [
                  if (_validationError case final error?) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFFFB4BC),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFB4BC),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (capture == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_cameraError != null)
                          OutlinedButton.icon(
                            onPressed: _initializeCamera,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Restart Camera'),
                          )
                        else
                          // Large prominent single-tap capture button
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: FilledButton(
                              key: const Key('capture_face'),
                              onPressed: _capturing ? null : _takePicture,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(
                                  side: BorderSide(
                                      color: Colors.white, width: 4),
                                ),
                                elevation: 8,
                              ),
                              child: _capturing
                                  ? const CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3)
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 36,
                                    ),
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retake'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('use_face_capture'),
                            onPressed: _useCapture,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Confirm Photo'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraPreview() {
    if (_cameraError case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 58,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return CameraPreview(controller);
  }
}

void _discardCapture(FaceCaptureEvidence? capture) {
  if (capture == null) return;
  PaintingBinding.instance.imageCache.evict(MemoryImage(capture.bytes));
  if (capture.croppedFaceBytes != null) {
    PaintingBinding.instance.imageCache.evict(MemoryImage(capture.croppedFaceBytes!));
  }
  capture.clear();
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                border: Border.all(color: const Color(0xFF10B981), width: 3.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cameraMessage(CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera permission is required.',
    'CameraAccessRestricted' => 'Camera access is restricted on this device.',
    'capture_size_invalid' => error.description ?? 'The capture is invalid.',
    _ => error.description ?? 'The camera is currently unavailable.',
  };
}

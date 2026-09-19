import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/platform/temp_capture_cleanup.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_observation_service_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_observation_service.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceCaptureEvidence? _capture;
  String? _error;
  bool _capturing = false;
  bool _returnedCapture = false;
  late final FaceObservationService _faceObserver;
  late String _challenge;
  int _livenessStage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceObserver = createFaceObservationService();
    _challenge = _newChallenge();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() => _error = null);
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
      await _controller?.dispose();
      setState(() => _controller = controller);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _error = _cameraMessage(error));
    } on Object {
      if (!mounted) return;
      setState(
        () => _error =
            'The camera could not be opened. Check browser or device permissions.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    String? temporaryPath;
    try {
      final file = await controller.takePicture();
      temporaryPath = file.path;
      final observation = await _faceObserver.observe(file.path);
      _validateObservation(observation);
      if (_livenessStage < 2) {
        if (!mounted) return;
        setState(() {
          _livenessStage += 1;
          _error = null;
        });
        return;
      }

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
      setState(() {
        _capture = FaceCaptureEvidence(
          bytes: bytes,
          contentType: 'image/jpeg',
          capturedAt: DateTime.now().toUtc(),
          livenessPassed: true,
          livenessChallenge: _challenge,
          faceBounds: observation.bounds,
        );
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraMessage(error));
    } on Object {
      if (mounted) {
        setState(() => _error = 'The face photo could not be captured.');
      }
    } finally {
      if (temporaryPath != null) {
        await deleteTemporaryCapture(temporaryPath);
      }
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _validateObservation(FaceObservation observation) {
    if (_livenessStage == 1) {
      final passed = switch (_challenge) {
        'smile' => (observation.smilingProbability ?? 0) >= .65,
        'turn_head' => observation.yaw.abs() >= 18,
        _ => false,
      };
      if (!passed) {
        throw AppFailure(
          code: FailureCode.invalidInput,
          message: _challenge == 'smile'
              ? 'A clear smile was not detected. Smile and try again.'
              : 'Turn your head farther to either side and try again.',
          diagnosticCode: 'LIVENESS_CHALLENGE_INCOMPLETE',
        );
      }
      return;
    }

    final leftEye = observation.leftEyeOpenProbability;
    final rightEye = observation.rightEyeOpenProbability;
    final eyesOpen =
        leftEye != null && rightEye != null && leftEye >= .5 && rightEye >= .5;
    if (observation.yaw.abs() > 14 || !eyesOpen) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Look directly at the camera with both eyes open.',
        diagnosticCode: 'FACE_ALIGNMENT_REQUIRED',
      );
    }
  }

  void _retake() {
    _discardCapture(_capture);
    setState(() {
      _capture = null;
      _error = null;
      _livenessStage = 0;
      _challenge = _newChallenge();
    });
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
    _controller?.dispose();
    unawaited(_faceObserver.dispose());
    if (!_returnedCapture) _discardCapture(_capture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Scaffold(
      backgroundColor: brand.heroStart,
      appBar: AppBar(
        backgroundColor: brand.heroStart,
        foregroundColor: Colors.white,
        title: const Text(
          'Face verification',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: Text(
                capture == null
                    ? _instruction
                    : 'Live challenge passed. Review your final temporary capture.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
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
                        if (capture == null && _error == null)
                          const _FaceGuideOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                children: [
                  if (_error case final error?) ...[
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB4BC)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (capture == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_error != null)
                          OutlinedButton.icon(
                            onPressed: _initializeCamera,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          )
                        else
                          SizedBox.square(
                            dimension: 76,
                            child: FilledButton(
                              key: const Key('capture_face'),
                              onPressed: _capturing ? null : _takePicture,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                shape: const CircleBorder(),
                              ),
                              child: _capturing
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 29,
                                        ),
                                        Text(
                                          '${_livenessStage + 1}/3',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
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
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Use photo'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Three fresh observations are checked on this device. Images are cleared if you cancel.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _instruction => switch (_livenessStage) {
    0 => 'Step 1 of 3 · Look directly at the camera with both eyes open.',
    1 when _challenge == 'smile' =>
      'Step 2 of 3 · Smile naturally for the live challenge.',
    1 => 'Step 2 of 3 · Turn your head clearly to either side.',
    _ => 'Step 3 of 3 · Look directly at the camera again.',
  };

  String _newChallenge() =>
      DateTime.now().microsecond.isEven ? 'smile' : 'turn_head';

  Widget _cameraPreview() {
    final controller = _controller;
    if (_error != null) {
      return const Center(
        child: Icon(
          Icons.no_photography_outlined,
          color: Colors.white54,
          size: 58,
        ),
      );
    }
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
  capture.clear();
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 220,
          height: 290,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(110),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}

String _cameraMessage(CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera permission is required. Enable it in browser or device settings.',
    'CameraAccessRestricted' => 'Camera access is restricted on this device.',
    'capture_size_invalid' => error.description ?? 'The capture is invalid.',
    _ => error.description ?? 'The camera is currently unavailable.',
  };
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/data/biometric_photo_crop_helper.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_verification_service.dart';

typedef PhotoDownloader = Future<Uint8List?> Function(String url);

FaceVerificationService createFaceVerificationService({
  PhotoDownloader? photoDownloader,
}) =>
    TfliteFaceVerificationService(photoDownloader: photoDownloader);

class TfliteFaceVerificationService implements FaceVerificationService {
  const TfliteFaceVerificationService({this.photoDownloader});

  final PhotoDownloader? photoDownloader;

  static const modelAsset = 'assets/models/mobile_facenet.tflite';
  static Interpreter? _cachedInterpreter;

  static Future<Interpreter> _getInterpreter() async {
    if (_cachedInterpreter != null) {
      return _cachedInterpreter!;
    }
    try {
      _cachedInterpreter = await Interpreter.fromAsset(modelAsset);
      return _cachedInterpreter!;
    } catch (e1) {
      debugPrint('[Biometrics] fromAsset failed: $e1. Trying rootBundle buffer...');
      try {
        final byteData = await rootBundle.load(modelAsset);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        _cachedInterpreter = Interpreter.fromBuffer(bytes);
        return _cachedInterpreter!;
      } catch (e2) {
        debugPrint('[Biometrics] fromBuffer failed: $e2');
        rethrow;
      }
    }
  }

  @override
  Future<LocalFaceVerification> verify({
    required FaceCaptureEvidence capture,
    required FaceBiometricProfile enrolledProfile,
  }) async {
    if (enrolledProfile.livenessRequired && !capture.livenessPassed) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Complete the live face challenge before continuing.',
        diagnosticCode: 'LIVENESS_REQUIRED',
      );
    }

    final faceBytes = capture.croppedFaceBytes ?? capture.bytes;
    final decoded = image.decodeImage(faceBytes);
    if (decoded == null) throw const FormatException('Invalid face image.');
    final oriented = image.bakeOrientation(decoded);
    final cropped = capture.croppedFaceBytes != null
        ? oriented
        : _cropFace(oriented, capture.faceBounds);

    List<double> liveEmbedding;

    try {
      final interpreter = await _getInterpreter();
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      final outputDim = outputShape.fold<int>(1, (total, value) => total * value);

      if (inputShape.length != 4 ||
          inputShape.first != 1 ||
          inputShape.last != 3 ||
          (outputDim != 192 && outputDim != 512 && outputDim != 128)) {
        throw const FormatException('Unsupported face model tensor shape.');
      }

      liveEmbedding = _extractTfliteEmbedding(
        interpreter,
        cropped,
        inputShape,
        outputShape,
      );
    } catch (e) {
      debugPrint('[Biometrics] TFLite inference failed: $e');
      throw AppFailure(
        code: FailureCode.invalidInput,
        message: 'On-device neural face verification failed: $e. Please verify device permissions and storage.',
        diagnosticCode: 'MODEL_INFERENCE_FAILED',
      );
    }

    // Reference vector is never stored on the mobile handset;
    // this 192-D Float32 vector is sent to the central server in the punch payload
    // where authoritative matching is performed against the enrolled template.
    return LocalFaceVerification(
      similarity: capture.livenessPassed ? 1.0 : 0.0,
      threshold: enrolledProfile.matchThreshold,
      livenessPassed:
          !enrolledProfile.livenessRequired || capture.livenessPassed,
      challenge: capture.livenessChallenge,
      modelVersion: 'MobileFaceNet (192-D)',
      liveVector: liveEmbedding,
    );
  }

  /// Extracts a 192-D MobileFaceNet unit vector from arbitrary photo bytes.
  /// Used for on-device vector generation during profile photo setup and enrollment.
  static Future<List<double>> extractEmbeddingFromBytes(Uint8List imageBytes) async {
    final observation = await BiometricPhotoCropHelper.detectFaceSilently(imageBytes);
    final croppedBytes = BiometricPhotoCropHelper.cropFaceOnly(
      imageBytes,
      observation?.bounds,
      eyeA: observation?.leftEye,
      eyeB: observation?.rightEye,
    );
    final decoded = image.decodeImage(croppedBytes ?? imageBytes);
    if (decoded == null) throw const FormatException('Invalid face image.');
    final cropped = image.bakeOrientation(decoded);

    try {
      final interpreter = await _getInterpreter();
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      return _extractTfliteEmbedding(
        interpreter,
        cropped,
        inputShape,
        outputShape,
      );
    } catch (e) {
      debugPrint('[Biometrics] extractEmbeddingFromBytes failed: $e');
      throw AppFailure(
        code: FailureCode.invalidInput,
        message: 'Failed to extract biometric vector from photo: $e',
        diagnosticCode: 'EMBEDDING_EXTRACTION_FAILED',
      );
    }
  }

  static List<double> _extractTfliteEmbedding(
    Interpreter interpreter,
    image.Image cropped,
    List<int> inputShape,
    List<int> outputShape,
  ) {
    final targetW = inputShape[2];
    final targetH = inputShape[1];
    final resized = image.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: image.Interpolation.linear,
    );
    final flatInput = <double>[];
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        flatInput
          ..add((pixel.r.toDouble() - 127.5) / 128.0)
          ..add((pixel.g.toDouble() - 127.5) / 128.0)
          ..add((pixel.b.toDouble() - 127.5) / 128.0);
      }
    }
    final input = flatInput.reshape<double>(inputShape);
    final outputDim = outputShape.fold<int>(1, (total, value) => total * value);
    final outputValues = List<double>.filled(outputDim, 0.0);
    final output = outputValues.reshape<double>(outputShape);
    interpreter.run(input, output);
    return _normalize(output.flatten<double>());
  }


  static List<double> _normalize(List<double> vector) {
    var sumSq = 0.0;
    for (final v in vector) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm <= 1e-6) {
      return List<double>.filled(vector.length, 0.0);
    }
    return vector.map((v) => v / norm).toList();
  }

  static image.Image _cropFace(image.Image source, FaceBounds? bounds) {
    if (bounds == null) {
      final side = math.min(source.width, source.height);
      return image.copyCrop(
        source,
        x: (source.width - side) ~/ 2,
        y: (source.height - side) ~/ 2,
        width: side,
        height: side,
      );
    }
    final padding = math.max(bounds.width, bounds.height) * .22;
    final left = math.max(0, (bounds.left - padding).floor());
    final top = math.max(0, (bounds.top - padding).floor());
    final right = math.min(
      source.width,
      (bounds.left + bounds.width + padding).ceil(),
    );
    final bottom = math.min(
      source.height,
      (bounds.top + bounds.height + padding).ceil(),
    );
    final width = right - left;
    final height = bottom - top;
    if (width < 32 || height < 32) throw const FormatException();
    return image.copyCrop(
      source,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }
}

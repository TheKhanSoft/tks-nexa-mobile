import 'dart:math' as math;

import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/data/cosine_face_matcher.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_verification_service.dart';

FaceVerificationService createFaceVerificationService() =>
    const TfliteFaceVerificationService();

class TfliteFaceVerificationService implements FaceVerificationService {
  const TfliteFaceVerificationService();

  static const modelAsset = 'assets/models/mobile_facenet.tflite';

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

    Interpreter? interpreter;
    try {
      interpreter = await Interpreter.fromAsset(modelAsset);
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (inputShape.length != 4 ||
          inputShape.first != 1 ||
          inputShape.last != 3 ||
          outputShape.fold<int>(1, (total, value) => total * value) != 512) {
        throw const FormatException('Unsupported face model tensor shape.');
      }

      final decoded = image.decodeImage(capture.bytes);
      if (decoded == null) throw const FormatException('Invalid face image.');
      final oriented = image.bakeOrientation(decoded);
      final cropped = _cropFace(oriented, capture.faceBounds);
      final resized = image.copyResize(
        cropped,
        width: inputShape[2],
        height: inputShape[1],
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
      final outputValues = List<double>.filled(512, 0);
      final output = outputValues.reshape<double>(outputShape);
      interpreter.run(input, output);
      final liveEmbedding = output.flatten<double>();
      final similarity = CosineFaceMatcher.compare(
        liveEmbedding,
        enrolledProfile.embedding,
      );
      return LocalFaceVerification(
        similarity: similarity,
        threshold: enrolledProfile.matchThreshold,
        livenessPassed:
            !enrolledProfile.livenessRequired || capture.livenessPassed,
        challenge: capture.livenessChallenge,
        modelVersion: enrolledProfile.modelVersion,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message:
            'The approved on-device face model is missing or incompatible.',
        diagnosticCode: 'FACE_MODEL_UNAVAILABLE',
      );
    } finally {
      interpreter?.close();
    }
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

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_observation_service.dart';

FaceObservationService createFaceObservationService() =>
    MlKitFaceObservationService();

class MlKitFaceObservationService implements FaceObservationService {
  MlKitFaceObservationService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  final FaceDetector _detector;

  @override
  Future<FaceObservation> observe(String imagePath) async {
    try {
      final faces = await _detector.processImage(
        InputImage.fromFilePath(imagePath),
      );
      if (faces.isEmpty) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'No face was detected. Center your face and try again.',
          diagnosticCode: 'FACE_NOT_DETECTED',
        );
      }
      if (faces.length != 1) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Only one person may be visible during verification.',
          diagnosticCode: 'MULTIPLE_FACES_DETECTED',
        );
      }
      final face = faces.single;
      final bounds = face.boundingBox;
      return FaceObservation(
        bounds: FaceBounds(
          left: bounds.left,
          top: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
        yaw: face.headEulerAngleY ?? 0,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        smilingProbability: face.smilingProbability,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message: 'The on-device face detector is temporarily unavailable.',
        diagnosticCode: 'FACE_DETECTOR_UNAVAILABLE',
      );
    }
  }

  @override
  Future<void> dispose() => _detector.close();
}

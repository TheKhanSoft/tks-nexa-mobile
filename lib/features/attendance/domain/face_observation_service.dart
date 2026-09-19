import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';

class FaceObservation {
  const FaceObservation({
    required this.bounds,
    required this.yaw,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.smilingProbability,
  });

  final FaceBounds bounds;
  final double yaw;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? smilingProbability;
}

abstract interface class FaceObservationService {
  Future<FaceObservation> observe(String imagePath);

  Future<void> dispose();
}

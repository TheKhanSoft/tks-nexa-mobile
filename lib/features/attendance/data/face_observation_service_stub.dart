import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_observation_service.dart';

FaceObservationService createFaceObservationService() =>
    const UnsupportedFaceObservationService();

class UnsupportedFaceObservationService implements FaceObservationService {
  const UnsupportedFaceObservationService();

  @override
  Future<FaceObservation> observe(String imagePath) {
    throw const AppFailure(
      code: FailureCode.unavailable,
      message: 'Live face challenges require the Android or iOS app.',
      diagnosticCode: 'LIVENESS_PLATFORM_UNSUPPORTED',
    );
  }

  @override
  Future<void> dispose() async {}
}

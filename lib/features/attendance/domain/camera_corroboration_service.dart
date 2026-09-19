import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';

abstract interface class CameraCorroborationService {
  Future<CameraCorroborationResult> getStatus({
    required String cameraChallengeId,
  });
}

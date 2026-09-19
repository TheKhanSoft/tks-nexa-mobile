import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_verification_service.dart';

FaceVerificationService createFaceVerificationService() =>
    const UnsupportedFaceVerificationService();

class UnsupportedFaceVerificationService implements FaceVerificationService {
  const UnsupportedFaceVerificationService();

  @override
  Future<LocalFaceVerification> verify({
    required FaceCaptureEvidence capture,
    required FaceBiometricProfile enrolledProfile,
  }) {
    throw const AppFailure(
      code: FailureCode.unavailable,
      message: 'On-device face matching requires the Android or iOS app.',
      diagnosticCode: 'FACE_MATCHING_PLATFORM_UNSUPPORTED',
    );
  }
}

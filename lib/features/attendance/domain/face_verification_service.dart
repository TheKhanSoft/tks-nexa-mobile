import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';

abstract interface class FaceVerificationService {
  Future<LocalFaceVerification> verify({
    required FaceCaptureEvidence capture,
    required FaceBiometricProfile enrolledProfile,
  });
}

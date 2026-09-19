import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';

abstract interface class MobileAttendanceService {
  Future<FaceBiometricProfile> fetchFaceProfile();

  Future<AttendanceChallenge> requestChallenge({required String deviceId});

  Future<void> registerDevice({
    required String deviceId,
    required DeviceKeyDetails key,
    required String appVersion,
  });

  Future<AttendanceMarkResult> markAttendance(AttendanceMarkRequest request);
}

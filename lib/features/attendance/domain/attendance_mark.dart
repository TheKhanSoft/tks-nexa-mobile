import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';

enum AttendanceType {
  checkIn('check_in'),
  checkOut('check_out');

  const AttendanceType(this.apiValue);
  final String apiValue;
}

class AttendanceMarkRequest {
  const AttendanceMarkRequest({
    required this.type,
    required this.verification,
    required this.location,
    required this.deviceId,
    required this.capturedAt,
    required this.challengeId,
    this.deviceSignature,
    this.integrityToken,
  });

  final AttendanceType type;
  final LocalFaceVerification verification;
  final LocationEvidence location;
  final String deviceId;
  final DateTime capturedAt;
  final String challengeId;
  final String? deviceSignature;
  final String? integrityToken;

  Map<String, Object> toJson() => {
    'challenge_id': challengeId,
    'attendance_type': type.apiValue,
    'verified_method': 'face_biometric',
    'verification_method': 'on_device_neural_engine',
    'confidence_score': verification.similarity,
    'similarity_score': verification.similarity,
    'match_threshold': verification.threshold,
    'liveness_passed': verification.livenessPassed,
    'liveness_verified': verification.livenessPassed,
    'liveness_challenge': verification.challenge,
    'face_model_version': verification.modelVersion,
    'timestamp': capturedAt.toUtc().toIso8601String(),
    'device_id': deviceId,
    'device_signature': ?deviceSignature,
    'play_integrity_token': ?integrityToken,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'horizontal_accuracy': location.horizontalAccuracyM,
    'location_captured_at': location.capturedAt.toUtc().toIso8601String(),
    'location_is_mocked': location.isMocked,
    'location': <String, Object>{
      'latitude': location.latitude,
      'longitude': location.longitude,
      'horizontal_accuracy': location.horizontalAccuracyM,
      'captured_at': location.capturedAt.toUtc().toIso8601String(),
    },
    'biometrics': <String, Object>{
      'similarity_score': verification.similarity,
      'liveness_verified': verification.livenessPassed,
      'verification_method': 'on_device_neural_engine',
    },
  };

  String canonicalPayload(String nonce) =>
      '$challengeId|$nonce|${location.latitude}|${location.longitude}|${location.capturedAt.toUtc().toIso8601String()}';
}

class AttendanceMarkResult {
  const AttendanceMarkResult({
    required this.message,
    this.attendanceId,
    this.recordedAt,
    this.type,
    this.trustScore,
    this.trustLevel,
    this.cameraCorroboration,
  });

  final String message;
  final String? attendanceId;
  final DateTime? recordedAt;
  final AttendanceType? type;
  final int? trustScore;
  final String? trustLevel;
  final CameraCorroborationResult? cameraCorroboration;
}

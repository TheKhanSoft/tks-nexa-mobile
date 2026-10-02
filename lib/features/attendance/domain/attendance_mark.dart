import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

enum AttendanceType {
  checkIn('check_in'),
  checkOut('check_out');

  const AttendanceType(this.apiValue);
  final String apiValue;
}

class AttendanceMarkRequest {
  const AttendanceMarkRequest({
    required this.verification,
    required this.location,
    required this.deviceId,
    required this.capturedAt,
    required this.challengeId,
    this.deviceSignature,
    this.integrityToken,
    this.deviceModel,
    this.osVersion,
    this.platform,
    this.locationName,
    this.snapshotBase64,
  });

  final LocalFaceVerification verification;
  final LocationEvidence location;
  final String deviceId;
  final DateTime capturedAt;
  final String challengeId;
  final String? deviceSignature;
  final String? integrityToken;
  final String? deviceModel;
  final String? osVersion;
  final String? platform;
  final String? locationName;
  final String? snapshotBase64;

  Map<String, Object> toJson() {
    final locName = locationName ?? location.locationName;
    final rawSim = verification.similarity;
    final clampedScore = (rawSim.isFinite && !rawSim.isNaN)
        ? (rawSim < 0.0 ? 0.0 : rawSim)
        : 0.0;

    return {
      'challenge_id': challengeId,
      'verified_method': 'face_biometric',
      'verification_method': 'FaceBiometric-EdgeNet-512',
      'confidence_score': clampedScore,
      'similarity_score': clampedScore,
      'match_threshold': 0.70,
      if (verification.liveVector != null)
        'face_vector': verification.liveVector!,
      'liveness_passed': verification.livenessPassed,
      'liveness_verified': verification.livenessPassed,
      'liveness_challenge': verification.challenge,
      'face_model_version': 'FaceBiometric-EdgeNet-512 (v1.0.0)',
      'timestamp': capturedAt.toIso8601String(),
      'device_id': deviceId,
      if (deviceModel != null) 'device_model': deviceModel!,
      if (osVersion != null) 'os_version': osVersion!,
      if (platform != null) 'platform': platform!,
      if (deviceSignature != null) 'device_signature': deviceSignature!,
      if (integrityToken != null) 'play_integrity_token': integrityToken!,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'horizontal_accuracy': location.horizontalAccuracyM,
      if (locName != null && locName.isNotEmpty) 'location_name': locName,
      'is_mocked': location.isMocked,
      if (snapshotBase64 != null) 'snapshot_base64': snapshotBase64!,
      'device_details': <String, Object>{
        'device_id': deviceId,
        'device_model': deviceModel ?? '',
        'os_version': osVersion ?? '',
        'platform': platform ?? '',
      },
      'location': <String, Object>{
        'latitude': location.latitude,
        'longitude': location.longitude,
        'horizontal_accuracy': location.horizontalAccuracyM,
        if (locName != null && locName.isNotEmpty) 'location_name': locName,
        'captured_at': location.capturedAt.toIso8601String(),
        'is_mocked': location.isMocked,
      },
      'biometrics': <String, Object>{
        'similarity_score': clampedScore,
        'liveness_verified': verification.livenessPassed,
        'verification_method': 'FaceBiometric-EdgeNet-512',
      },
    };
  }

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

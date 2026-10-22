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
    final clampedScore = (rawSim != null && rawSim.isFinite && !rawSim.isNaN)
        ? (rawSim < 0.0 ? 0.0 : rawSim)
        : null;

    final localCaptured = capturedAt.toLocal();
    final localDateStr =
        '${localCaptured.year}-${localCaptured.month.toString().padLeft(2, '0')}-${localCaptured.day.toString().padLeft(2, '0')}';
    final localTimeStr =
        '${localCaptured.hour.toString().padLeft(2, '0')}:${localCaptured.minute.toString().padLeft(2, '0')}:${localCaptured.second.toString().padLeft(2, '0')}';

    return {
      'challenge_id': challengeId,
      'verified_method': 'face_biometric',
      'verification_method': 'Face Biometric',
      if (clampedScore != null) ...{
        'confidence_score': clampedScore,
        'similarity_score': clampedScore,
      },
      'match_threshold': verification.threshold,
      if (verification.liveVector != null)
        'face_vector': verification.liveVector!,
      if (verification.mirroredVector != null) ...{
        'face_vector_mirrored': verification.mirroredVector!,
        'face_vector_flipped': verification.mirroredVector!,
      },
      'liveness_passed': verification.livenessPassed,
      'liveness_verified': verification.livenessPassed,
      'liveness_challenge': verification.challenge,
      'face_model_version': 'Face Biometric (v1.0)',
      'timestamp': capturedAt.toUtc().toIso8601String(),
      'recorded_at': capturedAt.toUtc().toIso8601String(),
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'client_timestamp': capturedAt.toUtc().toIso8601String(),
      'punch_time': localTimeStr,
      'punch_datetime': localCaptured.toIso8601String(),
      'attendance_date': localDateStr,
      'attendance_time': localTimeStr,
      'date': localDateStr,
      'time': localTimeStr,
      'device_id': deviceId,
      if (deviceModel != null) 'device_model': deviceModel!,
      if (osVersion != null) 'os_version': osVersion!,
      if (platform != null) 'platform': platform!,
      if (deviceSignature != null) 'device_signature': deviceSignature!,
      if (integrityToken != null) 'play_integrity_token': integrityToken!,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'horizontal_accuracy': location.horizontalAccuracyM,
      'is_mocked': location.isMocked,
      if (location.wifiBssid != null && location.wifiBssid!.isNotEmpty)
        'wifi_bssid': location.wifiBssid!,
      if (location.wifiSsid != null && location.wifiSsid!.isNotEmpty)
        'wifi_ssid': location.wifiSsid!,
      if (location.wifiGatewayIp != null && location.wifiGatewayIp!.isNotEmpty)
        'wifi_gateway_ip': location.wifiGatewayIp!,
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
        'captured_at': location.capturedAt.toUtc().toIso8601String(),
        'is_mocked': location.isMocked,
        if (location.wifiBssid != null && location.wifiBssid!.isNotEmpty)
          'wifi_bssid': location.wifiBssid!,
        if (location.wifiSsid != null && location.wifiSsid!.isNotEmpty)
          'wifi_ssid': location.wifiSsid!,
        if (location.wifiGatewayIp != null && location.wifiGatewayIp!.isNotEmpty)
          'wifi_gateway_ip': location.wifiGatewayIp!,
      },
      'biometrics': <String, Object>{
        if (clampedScore != null) 'similarity_score': clampedScore,
        if (verification.isOfflinePendingMatch) 'offline_pending_match': true,
        'liveness_verified': verification.livenessPassed,
        'verification_method': 'Face Biometric',
        if (verification.liveVector != null)
          'face_vector': verification.liveVector!,
        if (verification.mirroredVector != null) ...{
          'face_vector_mirrored': verification.mirroredVector!,
          'face_vector_flipped': verification.mirroredVector!,
        },
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
    this.similarityScore,
    this.trustScore,
    this.trustLevel,
    this.cameraCorroboration,
    this.isOffline = false,
  });

  final String message;
  final String? attendanceId;
  final DateTime? recordedAt;
  final AttendanceType? type;
  final double? similarityScore;
  final int? trustScore;
  final String? trustLevel;
  final CameraCorroborationResult? cameraCorroboration;
  final bool isOffline;
}

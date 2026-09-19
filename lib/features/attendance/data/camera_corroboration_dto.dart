import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';

class CameraCorroborationDto {
  const CameraCorroborationDto._();

  static CameraCorroborationResult fromStatusJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    if (rawStatus is! String) throw _invalidResponse;
    final status = _parseStatus(rawStatus);
    final challengeId = json['camera_challenge_id'];
    final rawExpiry = json['expires_at'];
    final expiry = rawExpiry is String
        ? DateTime.tryParse(rawExpiry)?.toUtc()
        : null;

    if ((status == CameraCorroborationStatus.challengeRequired ||
            status == CameraCorroborationStatus.waitingForCamera) &&
        (challengeId is! String || challengeId.isEmpty)) {
      throw _invalidResponse;
    }

    final remainingSeconds = json['remaining_seconds'];

    return CameraCorroborationResult(
      status: status,
      cameraChallengeId: challengeId is String ? challengeId : null,
      expiresAt: expiry,
      message: json['message'] is String ? json['message'] as String : null,
      remainingSeconds: remainingSeconds is int ? remainingSeconds : null,
      matchedCamera: json['matched_camera'] is String
          ? json['matched_camera'] as String
          : null,
    );
  }

  static CameraCorroborationResult fromAttendanceSubmissionJson(
    Map<String, dynamic> json,
  ) {
    final status = json['status'];
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : const <String, dynamic>{};
    final payload = <String, dynamic>{...json, ...data};
    if (status == 'camera_verification_required') {
      return fromStatusJson({
        ...payload,
        'status': 'challenge_required',
        'message': json['message'],
      });
    }
    if (status == 'accepted' &&
        (payload['camera_corroboration'] == 'already_verified' ||
            payload['camera_corroboration'] == 'already_corroborated')) {
      return const CameraCorroborationResult(
        status: CameraCorroborationStatus.alreadyCorroborated,
      );
    }
    if (status == 'accepted' || status == 'success') {
      return const CameraCorroborationResult(
        status: CameraCorroborationStatus.notRequired,
      );
    }
    throw _invalidResponse;
  }

  static CameraCorroborationStatus _parseStatus(String status) {
    return switch (status) {
      'not_required' => CameraCorroborationStatus.notRequired,
      'already_corroborated' ||
      'already_verified' => CameraCorroborationStatus.alreadyCorroborated,
      'challenge_required' || 'camera_verification_required' =>
        CameraCorroborationStatus.challengeRequired,
      'waiting_for_camera' ||
      'pending' => CameraCorroborationStatus.waitingForCamera,
      'verified' => CameraCorroborationStatus.verified,
      'expired' => CameraCorroborationStatus.expired,
      'failed' || 'cancelled' => CameraCorroborationStatus.failed,
      'unavailable' => CameraCorroborationStatus.unavailable,
      _ => throw _invalidResponse,
    };
  }

  static const AppFailure _invalidResponse = AppFailure(
    code: FailureCode.invalidResponse,
    message: 'Camera verification status could not be loaded.',
    diagnosticCode: 'CAMERA_CORROBORATION_INVALID',
  );
}

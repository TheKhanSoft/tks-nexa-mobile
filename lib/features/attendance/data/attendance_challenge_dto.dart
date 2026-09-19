import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';

class AttendanceChallengeDto {
  const AttendanceChallengeDto._();

  static AttendanceChallenge fromResponse(Object? response) {
    try {
      final root = _map(response);
      final data = _map(root['data']);
      final id = _requiredString(data['challenge_id']);
      final nonce = _requiredString(data['nonce']);
      final serverTimestamp = DateTime.parse(
        _requiredString(data['server_timestamp']),
      ).toUtc();
      final expiresAt = DateTime.parse(
        _requiredString(data['expires_at']),
      ).toUtc();
      if (!expiresAt.isAfter(serverTimestamp)) throw const FormatException();

      final policyJson = data['policy'] is Map
          ? _map(data['policy'])
          : const <String, dynamic>{};
      final locationJson = data['location'] is Map
          ? _map(data['location'])
          : null;

      return AttendanceChallenge(
        id: id,
        nonce: nonce,
        serverTimestamp: serverTimestamp,
        expiresAt: expiresAt,
        policy: AttendanceChallengePolicy(
          polygonGeofenceEnabled: _bool(
            policyJson['polygon_geofence_enabled'],
          ),
          requireAppIntegrity: _bool(policyJson['require_app_integrity']),
          cameraVerificationEnabled: _bool(
            policyJson['camera_verification_enabled'],
          ),
        ),
        location: locationJson == null
            ? null
            : AttendanceChallengeLocation(
                id: _requiredString(locationJson['id']),
                name: _requiredString(locationJson['name']),
                minimumAccuracyM:
                    _positiveNumber(locationJson['min_accuracy_meters']) ?? 50,
                polygon: _polygon(locationJson['polygon']),
              ),
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The attendance challenge response was incomplete.',
        diagnosticCode: 'ATTENDANCE_CHALLENGE_INVALID',
      );
    }
  }

  static List<AttendanceChallengePoint> _polygon(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException();
    return value.map((point) {
      if (point is! List || point.length < 2) throw const FormatException();
      final latitude = point[0];
      final longitude = point[1];
      if (latitude is! num || longitude is! num) {
        throw const FormatException();
      }
      return AttendanceChallengePoint(
        latitude.toDouble(),
        longitude.toDouble(),
      );
    }).toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }

  static String _requiredString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw const FormatException();
  }

  static bool _bool(Object? value) => value is bool ? value : false;

  static double? _positiveNumber(Object? value) {
    if (value is num && value.isFinite && value > 0) return value.toDouble();
    return null;
  }
}

import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_policy.dart';

class AttendancePolicyDto {
  const AttendancePolicyDto._();

  static AttendancePolicy fromJson(Map<String, dynamic> json) {
    try {
      return AttendancePolicy(
        mobileAttendanceEnabled: _requiredBool(
          json,
          'mobile_attendance_enabled',
        ),
        requireLocation: _requiredBool(json, 'require_location'),
        requireIntegrity: _requiredBool(json, 'require_integrity'),
        requireRegisteredDevice: _requiredBool(
          json,
          'require_registered_device',
        ),
        requireFace: _requiredBool(json, 'require_face'),
        requireLiveness: _requiredBool(json, 'require_liveness'),
        polygonGeofenceEnabled: _requiredBool(json, 'polygon_geofence_enabled'),
        cameraVerificationEnabled: _requiredBool(
          json,
          'camera_verification_enabled',
        ),
        bleProximityEnabled: _optionalBool(json, 'ble_proximity_enabled'),
        nfcProximityEnabled: _optionalBool(json, 'nfc_proximity_enabled'),
        uwbProximityEnabled: _optionalBool(json, 'uwb_proximity_enabled'),
        wifiRttProximityEnabled: _optionalBool(
          json,
          'wifi_rtt_proximity_enabled',
        ),
        maximumLocationAccuracyM: _optionalPositiveDouble(
          json['maximum_location_accuracy_m'],
        ),
      );
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The attendance policy could not be loaded.',
        diagnosticCode: 'ATTENDANCE_POLICY_INVALID',
      );
    }
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw const FormatException();
  }

  static bool _optionalBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is bool) return value;
    throw const FormatException();
  }

  static double? _optionalPositiveDouble(Object? value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite || value <= 0) {
      throw const FormatException();
    }
    return value.toDouble();
  }
}

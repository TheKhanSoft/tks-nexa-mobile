import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/attendance_policy_dto.dart';

void main() {
  test('defaults every optional hardware proximity method to disabled', () {
    final policy = AttendancePolicyDto.fromJson({
      'mobile_attendance_enabled': true,
      'require_location': true,
      'require_integrity': true,
      'require_registered_device': true,
      'require_face': true,
      'require_liveness': true,
      'polygon_geofence_enabled': true,
      'camera_verification_enabled': true,
      'maximum_location_accuracy_m': 50,
    });

    expect(policy.polygonGeofenceEnabled, isTrue);
    expect(policy.cameraVerificationEnabled, isTrue);
    expect(policy.bleProximityEnabled, isFalse);
    expect(policy.nfcProximityEnabled, isFalse);
    expect(policy.uwbProximityEnabled, isFalse);
    expect(policy.wifiRttProximityEnabled, isFalse);
  });
}

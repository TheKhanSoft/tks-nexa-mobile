import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

void main() {
  group('Device Security and Wi-Fi Evidence Tests', () {
    test('DeviceSecurityStatus flags are correctly reported', () {
      const clean = DeviceSecurityStatus(
        isRooted: false,
        isHooked: false,
        isTampered: false,
      );
      expect(clean.isRooted, isFalse);
      expect(clean.isHooked, isFalse);
      expect(clean.isTampered, isFalse);

      const rooted = DeviceSecurityStatus(
        isRooted: true,
        isHooked: false,
        isTampered: true,
        details: 'su_binary,magisk_mount',
      );
      expect(rooted.isRooted, isTrue);
      expect(rooted.isTampered, isTrue);
      expect(rooted.details, contains('su_binary'));

      const hooked = DeviceSecurityStatus(
        isRooted: false,
        isHooked: true,
        isTampered: true,
        details: 'xposed_class',
      );
      expect(hooked.isHooked, isTrue);
      expect(hooked.isTampered, isTrue);
      expect(hooked.details, contains('xposed_class'));
    });

    test('LocationEvidence serializes Wi-Fi BSSID, SSID, and Gateway IP in JSON', () {
      final loc = LocationEvidence(
        latitude: 34.1989,
        longitude: 72.0404,
        horizontalAccuracyM: 10,
        capturedAt: DateTime.utc(2026, 10, 15, 9, 0),
        wifiBssid: 'e0:28:6d:44:12:a8',
        wifiSsid: 'AWKUM-Campus-WiFi',
        wifiGatewayIp: '192.168.1.1',
      );

      final json = loc.toJson();
      expect(json['wifi_bssid'], equals('e0:28:6d:44:12:a8'));
      expect(json['wifi_ssid'], equals('AWKUM-Campus-WiFi'));
      expect(json['wifi_gateway_ip'], equals('192.168.1.1'));
    });

    test('AttendanceMarkRequest includes Wi-Fi BSSID and Gateway in top-level and location payload', () {
      final loc = LocationEvidence(
        latitude: 34.1989,
        longitude: 72.0404,
        horizontalAccuracyM: 10,
        capturedAt: DateTime.utc(2026, 10, 15, 9, 0),
        wifiBssid: 'e0:28:6d:44:12:a8',
        wifiSsid: 'AWKUM-Campus-WiFi',
        wifiGatewayIp: '192.168.1.1',
      );

      final req = AttendanceMarkRequest(
        verification: const LocalFaceVerification(
          similarity: 0.95,
          threshold: 0.75,
          livenessPassed: true,
          challenge: 'blink',
          modelVersion: 'mobile_facenet_v1',
        ),
        location: loc,
        deviceId: 'dev-123',
        capturedAt: DateTime.utc(2026, 10, 15, 9, 0),
        challengeId: 'chal-456',
      );

      final json = req.toJson();
      expect(json['wifi_bssid'], equals('e0:28:6d:44:12:a8'));
      expect(json['wifi_ssid'], equals('AWKUM-Campus-WiFi'));
      expect(json['wifi_gateway_ip'], equals('192.168.1.1'));

      final innerLoc = json['location'] as Map<String, Object>;
      expect(innerLoc['wifi_bssid'], equals('e0:28:6d:44:12:a8'));
      expect(innerLoc['wifi_ssid'], equals('AWKUM-Campus-WiFi'));
      expect(innerLoc['wifi_gateway_ip'], equals('192.168.1.1'));
    });
  });
}

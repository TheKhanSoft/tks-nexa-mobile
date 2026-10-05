import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_biometric_profile_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';

void main() {
  group('FaceBiometricProfileDto', () {
    test('parses 192-dimension neural embedding', () {
      final json = {
        'status': 'success',
        'data': {
          'employee_id': '42',
          'is_enrolled': true,
          'embedding': List<double>.filled(192, 0.05),
          'match_threshold': 0.70,
          'model': 'MobileFaceNet',
          'photo_url': 'https://api.tksnexa.me/photo.jpg',
        },
      };

      final profile = FaceBiometricProfileDto.fromResponse(json);
      expect(profile.employeeId, '42');
      expect(profile.embedding.length, 192);
      expect(profile.matchThreshold, 0.70);
      expect(profile.photoUrl, 'https://api.tksnexa.me/photo.jpg');
    });

    test('parses 512-dimension embedding', () {
      final json = {
        'status': 'success',
        'data': {
          'employee_id': '10',
          'is_enrolled': true,
          'embedding': List<double>.filled(512, 0.01),
          'match_threshold': 0.70,
        },
      };

      final profile = FaceBiometricProfileDto.fromResponse(json);
      expect(profile.embedding.length, 512);
    });

    test('parses profile with photo_url when embedding is empty', () {
      final json = {
        'status': 'success',
        'data': {
          'employee_id': '15',
          'is_enrolled': true,
          'photo_url': 'https://api.tksnexa.me/tenant/file/emp_15.jpg',
        },
      };

      final profile = FaceBiometricProfileDto.fromResponse(json);
      expect(profile.photoUrl, 'https://api.tksnexa.me/tenant/file/emp_15.jpg');
      expect(profile.embedding, isEmpty);
    });
  });
}

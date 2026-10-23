import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/security/offline_security_token_service.dart';

void main() {
  const secret = 'b8a7177f44e9529403c5979a27a201cff325213fb18f89c0942d7ffb2a24313e';

  group('OfflineSecurityTokenService', () {
    test('encrypts and successfully decrypts payload with valid secret', () {
      final payload = {
        'punch_id': 'offline_1792650000',
        'device_id': 'device_test_123',
        'captured_at': '2026-10-22T08:30:00.000Z',
        'device_wall_time_ms': 1792650000000,
        'punch_elapsed_realtime_ms': 5400000,
        'sync_elapsed_realtime_ms': 5700000,
        'monotonic_elapsed_ms': 300000,
        'is_auto_time': true,
        'clock_skew_seconds': 0,
        'is_time_manipulated': false,
        'payload_hash': 'a1b2c3d4e5f6',
      };

      final token = OfflineSecurityTokenService.createToken(
        payload: payload,
        secret: secret,
      );

      expect(token, isNotEmpty);
      expect(token.contains('.'), isTrue);

      final decrypted = OfflineSecurityTokenService.verifyAndDecryptToken(
        token: token,
        secret: secret,
      );

      expect(decrypted, isNotNull);
      expect(decrypted!['punch_id'], equals('offline_1792650000'));
      expect(decrypted['device_id'], equals('device_test_123'));
      expect(decrypted['monotonic_elapsed_ms'], equals(300000));
      expect(decrypted['is_auto_time'], isTrue);
      expect(decrypted['is_time_manipulated'], isFalse);
    });

    test('rejects token decrypted with wrong secret', () {
      final payload = {'punch_id': 'test'};
      final token = OfflineSecurityTokenService.createToken(
        payload: payload,
        secret: secret,
      );

      final decrypted = OfflineSecurityTokenService.verifyAndDecryptToken(
        token: token,
        secret: 'wrong_secret_123456789012345678901234567890123456789012345678',
      );

      expect(decrypted, isNull);
    });

    test('rejects token if ciphertext has been tampered with', () {
      final payload = {'punch_id': 'test'};
      final token = OfflineSecurityTokenService.createToken(
        payload: payload,
        secret: secret,
      );

      final parts = token.split('.');
      final tamperedEnvelope = parts[0].startsWith('X')
          ? 'Y${parts[0].substring(1)}'
          : 'X${parts[0].substring(1)}';
      final tamperedToken = '$tamperedEnvelope.${parts[1]}';

      final decrypted = OfflineSecurityTokenService.verifyAndDecryptToken(
        token: tamperedToken,
        secret: secret,
      );

      expect(decrypted, isNull);
    });
  });
}

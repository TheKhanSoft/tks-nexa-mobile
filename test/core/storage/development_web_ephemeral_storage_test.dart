import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/storage/development_web_ephemeral_storage.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';

void main() {
  test('uses primary storage while it is available', () async {
    final primary = _TestStorage();
    final storage = DevelopmentWebEphemeralStorage(primary);

    await storage.write('tenant', 'awkum');

    expect(await storage.read('tenant'), 'awkum');
    expect(primary.values['tenant'], 'awkum');
    expect(storage.usesEphemeralStorage, isFalse);
  });

  test(
    'falls back to memory without exposing values to browser storage',
    () async {
      final primary = _TestStorage(shouldFail: true);
      final storage = DevelopmentWebEphemeralStorage(primary);

      await storage.write('token', 'secret');

      expect(storage.usesEphemeralStorage, isTrue);
      expect(await storage.read('token'), 'secret');
      expect(await storage.readAll(), {'token': 'secret'});
      expect(primary.values, isEmpty);

      await storage.delete('token');
      expect(await storage.read('token'), isNull);
    },
  );
}

class _TestStorage implements SecureStorageService {
  _TestStorage({this.shouldFail = false});

  final bool shouldFail;
  final Map<String, String> values = <String, String>{};

  Never _fail() => throw StateError('WebCrypto unavailable');

  @override
  Future<void> delete(String key) async {
    if (shouldFail) _fail();
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (shouldFail) _fail();
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    if (shouldFail) _fail();
    return Map<String, String>.of(values);
  }

  @override
  Future<void> write(String key, String value) async {
    if (shouldFail) _fail();
    values[key] = value;
  }
}

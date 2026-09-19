import 'package:flutter/foundation.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';

/// Keeps development browser sessions usable when WebCrypto is unavailable.
///
/// `flutter_secure_storage_web` intentionally rejects non-secure origins such
/// as `http://192.168.x.x`. In that development-only situation, this wrapper
/// falls back to process memory. Values are never written to localStorage and
/// disappear when the Flutter application is restarted or the page is closed.
class DevelopmentWebEphemeralStorage implements SecureStorageService {
  DevelopmentWebEphemeralStorage(this._primary);

  final SecureStorageService _primary;
  final Map<String, String> _values = <String, String>{};
  bool _usesEphemeralStorage = false;

  @visibleForTesting
  bool get usesEphemeralStorage => _usesEphemeralStorage;

  @override
  Future<void> delete(String key) =>
      _execute(() => _primary.delete(key), () async => _values.remove(key));

  @override
  Future<String?> read(String key) =>
      _execute(() => _primary.read(key), () async => _values[key]);

  @override
  Future<Map<String, String>> readAll() =>
      _execute(_primary.readAll, () async => Map<String, String>.of(_values));

  @override
  Future<void> write(String key, String value) => _execute(
    () => _primary.write(key, value),
    () async => _values[key] = value,
  );

  Future<T> _execute<T>(
    Future<T> Function() primaryOperation,
    Future<T> Function() ephemeralOperation,
  ) async {
    if (_usesEphemeralStorage) return ephemeralOperation();
    try {
      return await primaryOperation();
    } on Object {
      _usesEphemeralStorage = true;
      debugPrint(
        'Secure WebCrypto storage is unavailable; using ephemeral memory for '
        'this development browser session.',
      );
      return ephemeralOperation();
    }
  }
}

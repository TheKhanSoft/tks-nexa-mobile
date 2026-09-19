import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

class SecureDeviceIdentity {
  const SecureDeviceIdentity(this._storage, this._tenantCode);

  final SecureStorageService _storage;
  final String _tenantCode;

  String get _key => 'tenant:${_tenantCode.toLowerCase()}:device_id';

  Future<String> getOrCreate() async {
    final current = await _storage.read(_key);
    if (current != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(current)) {
      return current;
    }
    final created = const Uuid().v4();
    await _storage.write(_key, created);
    return created;
  }
}

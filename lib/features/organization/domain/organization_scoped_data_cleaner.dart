import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

abstract interface class OrganizationScopedDataCleaner {
  Future<void> clearFor(Organization organization);
}

class SecureOrganizationScopedDataCleaner
    implements OrganizationScopedDataCleaner {
  SecureOrganizationScopedDataCleaner(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> clearFor(Organization organization) async {
    final prefix = 'tenant:${organization.code.toLowerCase()}:';
    final values = await _storage.readAll();
    for (final key in values.keys.where((key) => key.startsWith(prefix))) {
      await _storage.delete(key);
    }
  }
}

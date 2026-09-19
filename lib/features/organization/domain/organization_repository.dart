import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

abstract interface class OrganizationRepository {
  Future<List<Organization>> fetchTenants({String? search});

  Future<Organization> resolveByCode(String organizationCode);

  Future<List<Organization>> searchByName(String query);

  Future<Organization?> loadSelectedOrganization();

  Future<void> saveSelectedOrganization(Organization organization);

  Future<void> clearSelectedOrganization();
}

abstract interface class OrganizationStore {
  Future<Organization?> read();

  Future<void> write(Organization organization);

  Future<void> clear();
}

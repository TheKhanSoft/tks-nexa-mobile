import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

abstract interface class OrganizationDiscoveryService {
  Future<List<Organization>> fetchTenants({String? search});

  Future<Organization> resolveByCode(String organizationCode);

  Future<List<Organization>> searchByName(String query);
}

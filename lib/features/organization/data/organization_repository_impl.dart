import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_discovery_service.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_repository.dart';

class OrganizationRepositoryImpl implements OrganizationRepository {
  OrganizationRepositoryImpl(this._discoveryService, this._store);

  final OrganizationDiscoveryService _discoveryService;
  final OrganizationStore _store;

  @override
  Future<List<Organization>> fetchTenants({String? search}) =>
      _discoveryService.fetchTenants(search: search);

  @override
  Future<void> clearSelectedOrganization() => _store.clear();

  @override
  Future<Organization?> loadSelectedOrganization() => _store.read();

  @override
  Future<Organization> resolveByCode(String organizationCode) =>
      _discoveryService.resolveByCode(organizationCode);

  @override
  Future<void> saveSelectedOrganization(Organization organization) =>
      _store.write(organization);

  @override
  Future<List<Organization>> searchByName(String query) =>
      _discoveryService.searchByName(query);
}

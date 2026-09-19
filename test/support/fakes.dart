import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/auth/domain/auth_session.dart';
import 'package:tks_nexa_attendance/features/auth/domain/authentication_service.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_repository.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_scoped_data_cleaner.dart';

final testOrganization = Organization(
  code: 'ABC123',
  name: 'Example University',
  apiBaseUri: Uri(
    scheme: 'https',
    host: 'example.myattendance.test',
    path: '/api/mobile',
  ),
);

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class FakeOrganizationRepository implements OrganizationRepository {
  FakeOrganizationRepository({
    this.selected,
    Organization? resolved,
    List<Organization>? directory,
  }) : resolved = resolved ?? testOrganization,
       directory = directory ?? [resolved ?? testOrganization];

  Organization? selected;
  Organization resolved;
  final List<Organization> directory;
  final List<String> events = [];

  @override
  Future<List<Organization>> fetchTenants({String? search}) async {
    events.add('fetch:${search ?? ''}');
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return directory;
    return directory
        .where(
          (organization) =>
              organization.name.toLowerCase().contains(query) ||
              organization.code.toLowerCase().contains(query) ||
              organization.apiBaseUri.host.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Future<void> clearSelectedOrganization() async {
    events.add('clear-selection');
    selected = null;
  }

  @override
  Future<Organization?> loadSelectedOrganization() async => selected;

  @override
  Future<Organization> resolveByCode(String organizationCode) async {
    events.add('resolve:$organizationCode');
    return resolved;
  }

  @override
  Future<void> saveSelectedOrganization(Organization organization) async {
    events.add('save:${organization.code}');
    selected = organization;
  }

  @override
  Future<List<Organization>> searchByName(String query) =>
      fetchTenants(search: query);
}

class RecordingOrganizationDataCleaner
    implements OrganizationScopedDataCleaner {
  RecordingOrganizationDataCleaner([this.events]);

  final List<String>? events;
  Organization? cleared;

  @override
  Future<void> clearFor(Organization organization) async {
    cleared = organization;
    events?.add('clear-tenant:${organization.code}');
  }
}

class FakeAuthenticationService implements AuthenticationService {
  final List<(LoginMethod, String, String)> calls = [];

  @override
  Future<AuthSession> login({
    required LoginMethod method,
    required String identifier,
    required String password,
  }) async {
    calls.add((method, identifier, password));
    return const AuthSession(
      accessToken: 'employee-access-token',
      employeeName: 'Example Employee',
    );
  }
}

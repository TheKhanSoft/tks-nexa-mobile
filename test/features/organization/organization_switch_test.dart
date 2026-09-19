import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_scoped_data_cleaner.dart';

import '../../support/fakes.dart';

void main() {
  test(
    'secure cleaner deletes only the current organization namespace',
    () async {
      final storage = InMemorySecureStorage()
        ..values.addAll({
          'tenant:abc123:access_token': 'secret-one',
          'tenant:abc123:device_key_id': 'key-one',
          'tenant:xyz789:access_token': 'secret-two',
          'app:selected_organization:v1': 'selection',
        });
      final cleaner = SecureOrganizationScopedDataCleaner(storage);

      await cleaner.clearFor(testOrganization);

      expect(storage.values, isNot(contains('tenant:abc123:access_token')));
      expect(storage.values, isNot(contains('tenant:abc123:device_key_id')));
      expect(storage.values, contains('tenant:xyz789:access_token'));
      expect(storage.values, contains('app:selected_organization:v1'));
    },
  );

  test('changing organization clears tenant data before selection', () async {
    final events = <String>[];
    final repository = FakeOrganizationRepository(selected: testOrganization);
    repository.events.clear();
    final cleaner = RecordingOrganizationDataCleaner(events);
    final container = ProviderContainer(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(repository),
        organizationScopedDataCleanerProvider.overrideWithValue(cleaner),
      ],
    );
    addTearDown(container.dispose);

    await container.read(organizationSessionProvider.future);
    repository.events.clear();
    await container
        .read(organizationSessionProvider.notifier)
        .changeOrganization();

    expect(cleaner.cleared, testOrganization);
    expect(events, ['clear-tenant:ABC123']);
    expect(repository.events, ['clear-selection']);
    expect(container.read(organizationSessionProvider).value, isNull);
  });

  test(
    'selecting a different tenant clears the previous tenant data',
    () async {
      final events = <String>[];
      final repository = FakeOrganizationRepository(selected: testOrganization);
      final cleaner = RecordingOrganizationDataCleaner(events);
      final container = ProviderContainer(
        overrides: [
          organizationRepositoryProvider.overrideWithValue(repository),
          organizationScopedDataCleanerProvider.overrideWithValue(cleaner),
        ],
      );
      addTearDown(container.dispose);

      await container.read(organizationSessionProvider.future);
      repository.events.clear();
      final next = Organization(
        code: 'XYZ789',
        name: 'Next Organization',
        apiBaseUri: Uri.parse('https://next.myattendance.test/api/mobile/v1'),
      );
      await container.read(organizationSessionProvider.notifier).select(next);

      expect(cleaner.cleared, testOrganization);
      expect(events, ['clear-tenant:ABC123']);
      expect(repository.events, ['save:XYZ789']);
      expect(container.read(organizationSessionProvider).value, next);
    },
  );
}

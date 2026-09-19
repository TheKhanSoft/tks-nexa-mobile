import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/app/app.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

import '../../support/fakes.dart';

void main() {
  const mobileApiSecret =
      '0000000000000000000000000000000000000000000000000000000000000001';

  testWidgets('selects and securely persists an organization', (tester) async {
    final repository = FakeOrganizationRepository();
    final storage = InMemorySecureStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'development',
              discoveryBaseUrl: 'https://discovery.myattendance.test',
              tenantHostSuffixes: 'myattendance.test',
              mobileApiSecret: mobileApiSecret,
            ),
          ),
          secureStorageServiceProvider.overrideWithValue(storage),
          organizationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const TksNexaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Organization'), findsOneWidget);
    expect(find.text('Example University'), findsOneWidget);
    await tester.tap(find.byKey(const Key('organization_ABC123')));
    await tester.pumpAndSettle();

    expect(find.text('Employee Login'), findsOneWidget);
    expect(find.text('Example University'), findsOneWidget);
    expect(repository.selected, testOrganization);
    expect(repository.events, contains('save:ABC123'));
  });

  testWidgets('shows the selected tenant first and marks it recent', (
    tester,
  ) async {
    final otherOrganization = Organization(
      code: 'XYZ789',
      name: 'Another Organization',
      apiBaseUri: Uri.parse('https://another.myattendance.test/api/mobile/v1'),
    );
    final repository = FakeOrganizationRepository(
      selected: testOrganization,
      directory: [otherOrganization, testOrganization],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'development',
              discoveryBaseUrl: 'https://discovery.myattendance.test',
              tenantHostSuffixes: 'myattendance.test',
              mobileApiSecret: mobileApiSecret,
            ),
          ),
          secureStorageServiceProvider.overrideWithValue(
            InMemorySecureStorage(),
          ),
          organizationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const TksNexaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Organization'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    final recentY = tester
        .getTopLeft(find.byKey(const Key('organization_ABC123')))
        .dy;
    final otherY = tester
        .getTopLeft(find.byKey(const Key('organization_XYZ789')))
        .dy;
    expect(recentY, lessThan(otherY));

    await tester.enterText(
      find.byKey(const Key('organization_query')),
      'Another',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.events, contains('fetch:Another'));
    expect(find.text('Another Organization'), findsOneWidget);
    expect(find.text('Example University'), findsNothing);
  });
}

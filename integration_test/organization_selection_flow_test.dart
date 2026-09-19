import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tks_nexa_attendance/app/app.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('organization selection reaches the employee login screen', (
    tester,
  ) async {
    final repository = FakeOrganizationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'development',
              discoveryBaseUrl: 'https://discovery.myattendance.test',
              tenantHostSuffixes: 'myattendance.test',
              mobileApiSecret:
                  '0000000000000000000000000000000000000000000000000000000000000001',
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

    await tester.tap(find.byKey(const Key('organization_ABC123')));
    await tester.pumpAndSettle();

    expect(find.text('Employee Login'), findsOneWidget);
  });
}

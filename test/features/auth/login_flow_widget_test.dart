import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/app/app.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/features/account/data/employee_account_api.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/account/presentation/employee_avatar.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

import '../../support/fakes.dart';

class _MockEmployeeAccountApi extends Mock implements EmployeeAccountApi {}

void main() {
  testWidgets('selects a tenant and logs in by email', (tester) async {
    final repository = FakeOrganizationRepository();
    final storage = InMemorySecureStorage();
    final authentication = FakeAuthenticationService();
    final accountApi = _MockEmployeeAccountApi();
    when(accountApi.logout).thenAnswer((_) async {});
    when(accountApi.fetchProfile).thenAnswer(
      (_) async => const EmployeeProfile(
        name: 'Example Employee',
        email: 'employee@example.test',
        employeeCode: 'EMP-1',
        username: 'employee.one',
        fatherName: 'Example Parent',
        cnic: '35202-1234567-1',
        designation: 'Officer',
        designationGrade: 'BPS-18',
        office: 'Administration',
        campus: 'Main Campus',
        mobileNumber: '03001234567',
        gender: 'Other',
        isActive: true,
        faceEnrolled: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(
              environment: 'development',
              discoveryBaseUrl: 'http://api.localhost:8000',
              tenantHostSuffixes: 'localhost,myattendance.test',
              mobileApiSecret:
                  '0000000000000000000000000000000000000000000000000000000000000001',
            ),
          ),
          secureStorageServiceProvider.overrideWithValue(storage),
          organizationRepositoryProvider.overrideWithValue(repository),
          authenticationServiceProvider.overrideWithValue(authentication),
          employeeAccountApiProvider.overrideWithValue(accountApi),
        ],
        child: const TksNexaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('organization_ABC123')));
    await tester.pumpAndSettle();
    expect(find.text('Employee Login'), findsOneWidget);
    expect(find.text('Change organization'), findsOneWidget);

    expect(find.byKey(const Key('login_method_employee_code')), findsOneWidget);
    expect(find.byKey(const Key('login_method_username')), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_method_employee_code')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('login_identifier')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.labelText,
      'Employee ID / code',
    );

    await tester.tap(find.byKey(const Key('login_method_username')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('login_identifier')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.labelText,
      'Username',
    );

    await tester.tap(find.byKey(const Key('login_method_email')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('login_identifier')),
      'employee@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'correct-password',
    );
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(authentication.calls, [
      (LoginMethod.email, 'employee@example.test', 'correct-password'),
    ]);
    expect(
      storage.values['tenant:abc123:access_token'],
      'employee-access-token',
    );
    storage.values['tenant:abc123:face_biometric_profile'] =
        '{"employee_id":"1"}';
    expect(find.text('Hello, Example'), findsOneWidget);
    expect(find.text('Open camera attendance'), findsOneWidget);
    expect(find.byKey(const Key('camera_attendance')), findsOneWidget);
    expect(find.text('ABC123'), findsNothing);
    expect(find.textContaining('Environment:'), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Change organization'), findsNothing);

    await tester.tap(find.text('Personal information'));
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Officer (BPS-18)'), findsOneWidget);
    expect(find.text('EMP-1'), findsOneWidget);
    expect(find.text('employee.one'), findsOneWidget);
    expect(find.text('Active employee'), findsNothing);
    expect(find.text('Grade'), findsNothing);
    expect(find.byType(EmployeeAvatar), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Personal information'), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('Choose your organization'), findsOneWidget);
    expect(storage.values['tenant:abc123:access_token'], isNull);
    expect(storage.values['tenant:abc123:face_biometric_profile'], isNull);
  });
}

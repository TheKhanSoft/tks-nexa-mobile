import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/features/organization/data/secure_organization_store.dart';

import '../../support/fakes.dart';

void main() {
  test('round-trips an approved organization through secure storage', () async {
    final storage = InMemorySecureStorage();
    final store = SecureOrganizationStore(
      storage,
      TrustedEndpointValidator(
        allowedTenantHostSuffixes: {'myattendance.test'},
      ),
    );

    await store.write(testOrganization);
    final restored = await store.read();

    expect(restored, testOrganization);
    expect(storage.values.keys, contains('app:selected_organization:v1'));
  });
}

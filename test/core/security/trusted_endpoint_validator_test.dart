import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';

void main() {
  final validator = TrustedEndpointValidator(
    allowedTenantHostSuffixes: {'myattendance.test'},
  );

  test('accepts an HTTPS subdomain of an approved suffix', () {
    final uri = validator.validateTenantApiBaseUrl(
      'https://example.myattendance.test/api',
    );
    expect(uri.host, 'example.myattendance.test');
  });

  test('rejects HTTP and lookalike suffixes', () {
    for (final url in [
      'http://example.myattendance.test/api',
      'https://myattendance.test.attacker.example/api',
      'https://evilmyattendance.test/api',
    ]) {
      expect(
        () => validator.validateTenantApiBaseUrl(url),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            FailureCode.untrustedEndpoint,
          ),
        ),
      );
    }
  });

  test(
    'allows HTTP only for localhost when development override is enabled',
    () {
      final localValidator = TrustedEndpointValidator(
        allowedTenantHostSuffixes: {'localhost'},
        allowDevelopmentLocalHttp: true,
      );

      expect(
        localValidator
            .validateTenantApiBaseUrl(
              'http://beacon.localhost:8000/api/mobile/v1',
            )
            .host,
        'beacon.localhost',
      );
      expect(
        () => localValidator.validateTenantApiBaseUrl(
          'http://beacon.example:8000/api/mobile/v1',
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

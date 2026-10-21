import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';

void main() {
  const validSecret =
      '0000000000000000000000000000000000000000000000000000000000000001';

  group('AppConfig', () {
    test('parses a valid development configuration', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        discoveryBaseUrl: 'https://discovery.myattendance.test',
        tenantHostSuffixes: 'myattendance.test,partner.test',
        mobileApiSecret: validSecret,
        allowMockSecurity: true,
      );

      expect(config.environment, AppEnvironment.development);
      expect(config.discoveryBaseUri.scheme, 'https');
      expect(config.allowedTenantHostSuffixes, contains('partner.test'));
    });

    test('normalizes tenant host suffixes with leading dots, scheme, and ports', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        discoveryBaseUrl: 'https://discovery.myattendance.test',
        tenantHostSuffixes: '.myattendance.test, https://partner.test/, 10.10.190.66:8001',
        mobileApiSecret: validSecret,
        allowMockSecurity: true,
      );

      expect(config.allowedTenantHostSuffixes, contains('myattendance.test'));
      expect(config.allowedTenantHostSuffixes, contains('partner.test'));
      expect(config.allowedTenantHostSuffixes, contains('10.10.190.66'));
      expect(config.allowedTenantHostSuffixes.any((s) => s.startsWith('.')), isFalse);
    });

    test('rejects non-HTTPS discovery configuration', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          discoveryBaseUrl: 'http://discovery.myattendance.test',
          tenantHostSuffixes: 'myattendance.test',
          mobileApiSecret: validSecret,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('allows HTTP localhost only in development', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        discoveryBaseUrl: 'http://localhost:8000',
        tenantHostSuffixes: 'localhost',
        mobileApiSecret: validSecret,
      );

      expect(config.discoveryBaseUri, Uri.parse('http://localhost:8000'));
      expect(config.allowsLocalHttp, isTrue);
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          discoveryBaseUrl: 'http://localhost:8000',
          tenantHostSuffixes: 'localhost',
          mobileApiSecret: validSecret,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('allows an explicit native development API bridge', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        discoveryBaseUrl: 'http://api.localhost:8000',
        tenantHostSuffixes: 'localhost',
        mobileApiSecret: validSecret,
        developmentConnectHost: '10.10.190.46',
        developmentConnectPort: '8001',
        developmentConnectScheme: 'https',
      );

      expect(config.developmentConnectHost, '10.10.190.46');
      expect(config.developmentConnectPort, 8001);
      expect(config.developmentConnectScheme, 'https');
    });

    test('rejects an incomplete development API bridge', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          discoveryBaseUrl: 'http://api.localhost:8000',
          tenantHostSuffixes: 'localhost',
          mobileApiSecret: validSecret,
          developmentConnectHost: '10.10.190.46',
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('rejects mock security in a release build', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          discoveryBaseUrl: 'https://discovery.myattendance.test',
          tenantHostSuffixes: 'myattendance.test',
          mobileApiSecret: validSecret,
          allowMockSecurity: true,
          isReleaseMode: true,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('requires production environment for release builds', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'staging',
          discoveryBaseUrl: 'https://discovery.myattendance.test',
          tenantHostSuffixes: 'myattendance.test',
          mobileApiSecret: validSecret,
          isReleaseMode: true,
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });

    test('rejects a missing or malformed mobile API secret', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          discoveryBaseUrl: 'https://discovery.myattendance.test',
          tenantHostSuffixes: 'myattendance.test',
          mobileApiSecret: 'not-a-hex-key',
        ),
        throwsA(isA<AppConfigurationException>()),
      );
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/core/network/local_development_host_interceptor.dart';
import 'package:tks_nexa_attendance/core/network/mobile_request_signature_interceptor.dart';

class _MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

void main() {
  const secret =
      '0000000000000000000000000000000000000000000000000000000000000001';

  test('routes a local subdomain through loopback and preserves Host', () {
    final interceptor = LocalDevelopmentHostInterceptor();
    final options = RequestOptions(
      baseUrl: 'http://api.localhost:8000/',
      path: 'mobile/v1/tenant-list',
    );
    final handler = _MockRequestInterceptorHandler();

    interceptor.onRequest(options, handler);

    expect(options.uri.host, 'localhost');
    expect(options.uri.port, 8000);
    expect(options.uri.path, '/mobile/v1/tenant-list');
    expect(options.headers['Host'], 'api.localhost:8000');
    verify(() => handler.next(options)).called(1);
  });

  test('routes through a development bridge without changing tenant Host', () {
    final interceptor = LocalDevelopmentHostInterceptor(
      connectHost: '10.10.190.46',
      connectPort: 8001,
    );
    final options = RequestOptions(
      baseUrl: 'http://awkum.localhost:8000/',
      path: 'api/mobile/profile',
    );
    final handler = _MockRequestInterceptorHandler();

    interceptor.onRequest(options, handler);

    expect(options.uri.host, '10.10.190.46');
    expect(options.uri.port, 8001);
    expect(options.headers['Host'], 'awkum.localhost:8000');
    expect(options.uri.path, '/api/mobile/profile');
    verify(() => handler.next(options)).called(1);
  });

  test('uses the same mobile signer for central and tenant clients', () {
    final config = AppConfig.fromValues(
      environment: 'development',
      discoveryBaseUrl: 'http://api.localhost:8000',
      tenantHostSuffixes: 'localhost',
      mobileApiSecret: secret,
    );

    final central = DioFactory.createDiscoveryClient(config);
    final tenant = DioFactory.createTenantClient(
      config,
      Uri.parse('http://beacon.localhost:8000/api/mobile'),
    );

    for (final client in [central, tenant]) {
      expect(
        client.interceptors.whereType<MobileRequestSignatureInterceptor>(),
        hasLength(1),
      );
      expect(
        client.interceptors.whereType<LocalDevelopmentHostInterceptor>(),
        hasLength(1),
      );
    }
  });

  test('tenant client always uses the tenant mobile API path', () {
    final config = AppConfig.fromValues(
      environment: 'development',
      discoveryBaseUrl: 'http://api.localhost:8000',
      tenantHostSuffixes: 'localhost',
      mobileApiSecret: secret,
    );

    final tenant = DioFactory.createTenantClient(
      config,
      Uri.parse('http://awkum.localhost:8000/api'),
    );

    expect(tenant.options.baseUrl, 'http://awkum.localhost:8000/api/mobile/');
  });
}

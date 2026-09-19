import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/features/organization/data/discovery_api.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late Dio dio;
  late DiscoveryApi api;

  setUp(() {
    dio = _MockDio();
    api = DiscoveryApi(
      dio,
      TrustedEndpointValidator(
        allowedTenantHostSuffixes: {'myattendance.test'},
      ),
      Uri.parse('https://discovery.myattendance.test'),
    );
  });

  test('tenant-list path is relative to the configured central API base', () {
    expect(DiscoveryApi.tenantListPath, 'mobile/v1/tenant-list');
    expect(
      Uri.parse(
        'https://api.mydomain.test/api/',
      ).resolve(DiscoveryApi.tenantListPath),
      Uri.parse('https://api.mydomain.test/api/mobile/v1/tenant-list'),
    );
  });

  test('loads active tenants from the signed directory endpoint', () async {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tenant-list'),
        statusCode: 200,
        data: {
          'status': 'success',
          'count': 1,
          'data': [
            {
              'id': '01JACTIVEDIR0000000000002',
              'public_id': '01JACTIVEDIR0000000000002',
              'name': 'Beacon Industries',
              'slug': 'beacon-ind',
              'status': 'active',
              'domain': 'beacon.myattendance.test',
              'domains': ['beacon.myattendance.test'],
              'created_at': '2026-09-17T05:27:06+00:00',
            },
          ],
        },
      ),
    );

    final organizations = await api.fetchTenants();

    expect(organizations, hasLength(1));
    expect(organizations.single.name, 'Beacon Industries');
    expect(
      organizations.single.apiBaseUri,
      Uri.parse('https://beacon.myattendance.test/api/mobile'),
    );
    verify(
      () =>
          dio.get<dynamic>(DiscoveryApi.tenantListPath, queryParameters: null),
    ).called(1);
  });

  test('sends search as a GET query parameter', () async {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tenant-list'),
        statusCode: 200,
        data: {'status': 'success', 'count': 0, 'data': <dynamic>[]},
      ),
    );

    await api.searchByName('Beacon');

    verify(
      () => dio.get<dynamic>(
        DiscoveryApi.tenantListPath,
        queryParameters: {'search': 'Beacon'},
      ),
    ).called(1);
  });

  test('rejects an unapproved tenant domain', () async {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tenant-list'),
        statusCode: 200,
        data: {
          'status': 'success',
          'count': 1,
          'data': [
            {
              'public_id': '01JACTIVEDIR0000000000002',
              'name': 'Imposter',
              'status': 'active',
              'domain': 'attacker.example',
            },
          ],
        },
      ),
    );

    expect(
      api.fetchTenants,
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.untrustedEndpoint,
        ),
      ),
    );
  });

  test('rejects an inconsistent response count', () async {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tenant-list'),
        statusCode: 200,
        data: {'status': 'success', 'count': 1, 'data': <dynamic>[]},
      ),
    );

    expect(
      api.fetchTenants,
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.invalidResponse,
        ),
      ),
    );
  });

  test('builds the local tenant API origin and mobile v1 base path', () async {
    final localApi = DiscoveryApi(
      dio,
      TrustedEndpointValidator(
        allowedTenantHostSuffixes: {'localhost'},
        allowDevelopmentLocalHttp: true,
      ),
      Uri.parse('http://api.localhost:8000'),
    );
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/tenant-list'),
        statusCode: 200,
        data: {
          'status': 'success',
          'count': 1,
          'data': [
            {
              'public_id': 'LOCAL001',
              'name': 'Local Tenant',
              'status': 'active',
              'domain': 'beacon.localhost',
            },
          ],
        },
      ),
    );

    final organizations = await localApi.fetchTenants();

    expect(
      organizations.single.apiBaseUri,
      Uri.parse('http://beacon.localhost:8000/api/mobile'),
    );
  });
}

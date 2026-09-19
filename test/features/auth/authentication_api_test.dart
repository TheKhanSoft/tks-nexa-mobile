import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/features/auth/data/authentication_api.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  test('posts the selected login type and parses the access token', () async {
    final dio = _MockDio();
    final api = AuthenticationApi(dio);
    when(
      () => dio.post<dynamic>(any(), data: any<dynamic>(named: 'data')),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: 'auth/login'),
        statusCode: 200,
        data: {
          'status': 'success',
          'data': {
            'access_token': 'token-value',
            'employee': {
              'name': 'Example Employee',
              'photo_url':
                  'https://tenant.example/file/employee.jpg?expires=123&signature=abc',
            },
          },
        },
      ),
    );

    final session = await api.login(
      method: LoginMethod.cnic,
      identifier: '3520212345671',
      password: 'password-value',
    );

    expect(session.accessToken, 'token-value');
    expect(session.employeeName, 'Example Employee');
    expect(
      session.photoUrl,
      'https://tenant.example/file/employee.jpg?expires=123&signature=abc',
    );
    verify(
      () => dio.post<dynamic>(
        AuthenticationApi.loginPath,
        data: {
          'login_type': 'cnic',
          'login': '3520212345671',
          'password': 'password-value',
        },
      ),
    ).called(1);
  });

  for (final testCase in [
    (LoginMethod.employeeCode, 'employee_code', 'PK-TEST-0001'),
    (LoginMethod.username, 'username', 'ibrahim.y'),
  ]) {
    test('supports ${testCase.$2} login', () async {
      final dio = _MockDio();
      final api = AuthenticationApi(dio);
      when(
        () => dio.post<dynamic>(any(), data: any<dynamic>(named: 'data')),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: 'auth/login'),
          statusCode: 200,
          data: {'access_token': 'token-value'},
        ),
      );

      await api.login(
        method: testCase.$1,
        identifier: '  ${testCase.$3}  ',
        password: 'password-value',
      );

      verify(
        () => dio.post<dynamic>(
          AuthenticationApi.loginPath,
          data: {
            'login_type': testCase.$2,
            'login': testCase.$3,
            'password': 'password-value',
          },
        ),
      ).called(1);
    });
  }
}

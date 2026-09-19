import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/auth/domain/auth_session.dart';
import 'package:tks_nexa_attendance/features/auth/domain/authentication_service.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';

class AuthenticationApi implements AuthenticationService {
  AuthenticationApi(this._dio);

  static const loginPath = 'auth/login';

  final Dio _dio;

  @override
  Future<AuthSession> login({
    required LoginMethod method,
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty || password.isEmpty) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Enter your login details and password.',
        diagnosticCode: 'LOGIN_INPUT_REQUIRED',
      );
    }

    try {
      final response = await _dio.post<dynamic>(
        loginPath,
        data: {
          'login_type': method.apiValue,
          'login': normalizedIdentifier,
          'password': password,
        },
      );
      final root = _asMap(response.data);
      final payload = root['data'] is Map ? _asMap(root['data']) : root;
      final token = payload['access_token'] ?? payload['token'];
      if (token is! String || token.trim().isEmpty) throw _invalidResponse;

      final employee = payload['employee'];
      String? employeeName;
      String? photoUrl;
      if (employee is Map) {
        final name = employee['full_name'] ?? employee['name'];
        if (name is String && name.trim().isNotEmpty) {
          employeeName = name.trim();
        }
        final rawPhotoUrl = employee['photo_url'];
        if (rawPhotoUrl is String && rawPhotoUrl.trim().isNotEmpty) {
          photoUrl = rawPhotoUrl.trim();
        }
      }
      return AuthSession(
        accessToken: token.trim(),
        employeeName: employeeName,
        photoUrl: photoUrl,
      );
    } on DioException catch (error) {
      throw switch (error.response?.statusCode) {
        401 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'The login details or password are incorrect.',
          diagnosticCode: 'LOGIN_REJECTED',
        ),
        403 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'This account cannot use mobile login.',
          diagnosticCode: 'LOGIN_FORBIDDEN',
        ),
        422 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Check your login details and try again.',
          diagnosticCode: 'LOGIN_VALIDATION_FAILED',
        ),
        429 => const AppFailure(
          code: FailureCode.rateLimited,
          message: 'Too many login attempts. Please wait and try again.',
          diagnosticCode: 'LOGIN_RATE_LIMITED',
        ),
        _ => const AppFailure(
          code: FailureCode.unavailable,
          message: 'Login is temporarily unavailable.',
          diagnosticCode: 'LOGIN_UNAVAILABLE',
        ),
      };
    } on AppFailure {
      rethrow;
    } on Object {
      throw _invalidResponse;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw _invalidResponse;
  }

  static const _invalidResponse = AppFailure(
    code: FailureCode.invalidResponse,
    message: 'The login service returned an invalid response.',
    diagnosticCode: 'LOGIN_RESPONSE_INVALID',
  );
}

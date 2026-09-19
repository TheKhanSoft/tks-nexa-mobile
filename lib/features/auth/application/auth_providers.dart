import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/features/account/data/employee_account_api.dart';
import 'package:tks_nexa_attendance/features/auth/data/authentication_api.dart';
import 'package:tks_nexa_attendance/features/auth/domain/auth_session.dart';
import 'package:tks_nexa_attendance/features/auth/domain/authentication_service.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  final organization = ref.watch(organizationSessionProvider).value;
  if (organization == null) {
    throw StateError('An organization must be selected before login.');
  }
  final config = ref.watch(appConfigProvider);
  return AuthenticationApi(
    DioFactory.createTenantClient(config, organization.apiBaseUri),
  );
});

final employeeAccountApiProvider = Provider<EmployeeAccountApi>((ref) {
  final organization = ref.watch(organizationSessionProvider).value;
  final session = ref.watch(currentAuthSessionProvider);
  if (organization == null || session == null) {
    throw StateError('An authenticated tenant session is required.');
  }
  return EmployeeAccountApi(
    DioFactory.createTenantClient(
      ref.watch(appConfigProvider),
      organization.apiBaseUri,
    ),
    session.accessToken,
  );
});

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);

final currentAuthSessionProvider =
    NotifierProvider<CurrentAuthSessionController, AuthSession?>(
      CurrentAuthSessionController.new,
    );

class CurrentAuthSessionController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void setSession(AuthSession session) => state = session;

  void clear() => state = null;
}

class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> login({
    required LoginMethod method,
    required String identifier,
    required String password,
  }) async {
    final organization = ref.read(organizationSessionProvider).value;
    if (organization == null) return false;

    state = const AsyncLoading();
    try {
      final session = await ref
          .read(authenticationServiceProvider)
          .login(method: method, identifier: identifier, password: password);
      await ref
          .read(secureStorageServiceProvider)
          .write(
            'tenant:${organization.code.toLowerCase()}:access_token',
            session.accessToken,
          );
      ref.read(currentAuthSessionProvider.notifier).setSession(session);
      state = const AsyncData(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> logout() async {
    final organization = ref.read(organizationSessionProvider).value;
    final session = ref.read(currentAuthSessionProvider);
    if (organization != null) {
      if (session != null) {
        try {
          await ref.read(employeeAccountApiProvider).logout();
        } on Object {
          // Local logout must still succeed if the server session expired.
        }
      }
      await ref
          .read(secureStorageServiceProvider)
          .delete('tenant:${organization.code.toLowerCase()}:access_token');
      await ref
          .read(secureStorageServiceProvider)
          .delete(
            'tenant:${organization.code.toLowerCase()}:face_biometric_profile',
          );
    }
    ref.read(currentAuthSessionProvider.notifier).clear();
    state = const AsyncData(null);
  }
}

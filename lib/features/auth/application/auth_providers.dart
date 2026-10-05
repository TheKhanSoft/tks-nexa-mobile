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

  void updateAfterPasswordChanged() {
    final current = state;
    if (current != null) {
      final updated = current.clearPasswordChangeRequirement();
      state = updated;
      _persistSession(updated);
    }
  }

  void updatePhotoUrl(String newPhotoUrl) {
    final current = state;
    if (current != null) {
      final updated = current.copyWith(
        photoUrl: newPhotoUrl,
        hasPhoto: true,
        actionRequired: current.actionRequired == 'upload_photo' ? null : current.actionRequired,
      );
      state = updated;
      _persistSession(updated);
    }
  }

  void _persistSession(AuthSession session) {
    final organization = ref.read(organizationSessionProvider).value;
    if (organization != null) {
      final storage = ref.read(secureStorageServiceProvider);
      final key = 'tenant:${organization.code.toLowerCase()}';
      storage.write('$key:auth_session', session.encode());
    }
  }

  Future<AuthSession?> restoreForOrganization(String organizationCode) async {
    final storage = ref.read(secureStorageServiceProvider);
    final rawSession = await storage.read(
      'tenant:${organizationCode.toLowerCase()}:auth_session',
    );
    var session = AuthSession.decode(rawSession);
    if (session == null) {
      final rawToken = await storage.read(
        'tenant:${organizationCode.toLowerCase()}:access_token',
      );
      if (rawToken != null && rawToken.trim().isNotEmpty) {
        session = AuthSession(accessToken: rawToken.trim());
      }
    }
    if (session != null) {
      state = session;
    }
    return session;
  }
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
      final storage = ref.read(secureStorageServiceProvider);
      final key = 'tenant:${organization.code.toLowerCase()}';
      await storage.write('$key:access_token', session.accessToken);
      await storage.write('$key:auth_session', session.encode());
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
      final storage = ref.read(secureStorageServiceProvider);
      final key = 'tenant:${organization.code.toLowerCase()}';
      await storage.delete('$key:access_token');
      await storage.delete('$key:auth_session');
      await storage.delete('$key:face_biometric_profile');
    }
    ref.read(currentAuthSessionProvider.notifier).clear();
    state = const AsyncData(null);
  }
}

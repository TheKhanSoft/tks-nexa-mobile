import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';

final employeeProfileProvider = FutureProvider<EmployeeProfile>(
  (ref) => ref.watch(employeeAccountApiProvider).fetchProfile(),
);

final changePasswordControllerProvider =
    AsyncNotifierProvider<ChangePasswordController, void>(
      ChangePasswordController.new,
    );

class ChangePasswordController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(employeeAccountApiProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = const AsyncData(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

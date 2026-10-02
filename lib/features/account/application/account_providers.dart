import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

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
      ref.read(currentAuthSessionProvider.notifier).updateAfterPasswordChanged();
      ref.invalidate(employeeProfileProvider);
      state = const AsyncData(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final photoUploadControllerProvider =
    AsyncNotifierProvider<PhotoUploadController, String?>(
      PhotoUploadController.new,
    );

class PhotoUploadController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> uploadPhoto({
    Uint8List? photoBytes,
    String? photoBase64,
  }) async {
    state = const AsyncLoading();
    try {
      final photoUrl = await ref
          .read(employeeAccountApiProvider)
          .uploadProfilePhoto(
            photoBytes: photoBytes,
            photoBase64: photoBase64,
          );
      state = AsyncData(photoUrl);
      if (photoUrl.isNotEmpty) {
        ref.read(currentAuthSessionProvider.notifier).updatePhotoUrl(photoUrl);
        ref.invalidate(employeeProfileProvider);
        ref.invalidate(faceBiometricProfileProvider);
      }
      return photoUrl;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}

class AppPreferences {
  const AppPreferences({
    this.use24HourTime = false,
    this.dataSaver = false,
    this.rememberTab = true,
  });

  final bool use24HourTime;
  final bool dataSaver;
  final bool rememberTab;

  AppPreferences copyWith({
    bool? use24HourTime,
    bool? dataSaver,
    bool? rememberTab,
  }) {
    return AppPreferences(
      use24HourTime: use24HourTime ?? this.use24HourTime,
      dataSaver: dataSaver ?? this.dataSaver,
      rememberTab: rememberTab ?? this.rememberTab,
    );
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  static const _prefix = 'preference:app:';

  @override
  Future<AppPreferences> build() async {
    final storage = ref.watch(secureStorageServiceProvider);
    final is24 = await storage.read('${_prefix}24_hour_time');
    final dataSaver = await storage.read('${_prefix}data_saver');
    final remember = await storage.read('${_prefix}remember_tab');

    return AppPreferences(
      use24HourTime: is24 == 'true',
      dataSaver: dataSaver == 'true',
      rememberTab: remember != 'false',
    );
  }

  Future<void> setUse24HourTime(bool value) async {
    final current = state.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(use24HourTime: value));
    await ref
        .read(secureStorageServiceProvider)
        .write('${_prefix}24_hour_time', value.toString());
  }

  Future<void> setDataSaver(bool value) async {
    final current = state.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(dataSaver: value));
    await ref
        .read(secureStorageServiceProvider)
        .write('${_prefix}data_saver', value.toString());
  }

  Future<void> setRememberTab(bool value) async {
    final current = state.value ?? const AppPreferences();
    state = AsyncData(current.copyWith(rememberTab: value));
    await ref
        .read(secureStorageServiceProvider)
        .write('${_prefix}remember_tab', value.toString());
  }
}

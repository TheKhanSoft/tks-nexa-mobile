import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/features/account/presentation/account_screens.dart';
import 'package:tks_nexa_attendance/features/auth/presentation/login_screen.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/attendance_preparation_screen.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/camera_verification_screen.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/organization_confirmation_screen.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/organization_qr_screen.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/organization_selection_screen.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/phase_one_home_screen.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/startup_screen.dart';

abstract final class AppRoutes {
  static const startup = '/';
  static const organizationSelection = '/organization/select';
  static const organizationConfirmation = '/organization/confirm';
  static const organizationQr = '/organization/qr';
  static const login = '/auth/login';
  static const home = '/home';
  static const cameraVerification = '/attendance/camera-verification';
  static const attendancePreparation = '/attendance/prepare';
  static const personalInformation = '/account/personal-information';
  static const notificationPreferences = '/account/notifications';
  static const securityDevices = '/account/security-devices';
  static const appSettings = '/account/settings';
  static const changePassword = '/account/change-password';
}

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.startup,
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.organizationSelection,
        builder: (context, state) => const OrganizationSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.organizationConfirmation,
        builder: (context, state) {
          final organization = state.extra;
          if (organization is! Organization) {
            return const OrganizationSelectionScreen();
          }
          return OrganizationConfirmationScreen(organization: organization);
        },
      ),
      GoRoute(
        path: AppRoutes.organizationQr,
        builder: (context, state) => const OrganizationQrScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PhaseOneHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.attendancePreparation,
        builder: (context, state) => const AttendancePreparationScreen(),
      ),
      GoRoute(
        path: AppRoutes.personalInformation,
        builder: (context, state) => const PersonalInformationScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.securityDevices,
        builder: (context, state) => const SecurityDevicesScreen(),
      ),
      GoRoute(
        path: AppRoutes.appSettings,
        builder: (context, state) => const AppSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.cameraVerification,
        builder: (context, state) {
          final result = state.extra;
          if (result is! CameraCorroborationResult) {
            return const PhaseOneHomeScreen();
          }
          return CameraVerificationScreen(initialResult: result);
        },
      ),
    ],
  ),
);

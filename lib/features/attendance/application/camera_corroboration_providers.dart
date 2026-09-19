import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/data/camera_corroboration_api.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration_service.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

final cameraCorroborationServiceProvider = Provider<CameraCorroborationService>(
  (ref) {
    final organization = ref.watch(organizationSessionProvider).value;
    final session = ref.watch(currentAuthSessionProvider);
    if (organization == null || session == null) {
      throw StateError('An authenticated tenant session is required.');
    }
    return CameraCorroborationApi(
      DioFactory.createTenantClient(
        ref.watch(appConfigProvider),
        organization.apiBaseUri,
      ),
      session.accessToken,
    );
  },
);

final cameraClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

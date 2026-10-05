import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_verification_service_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/data/mobile_attendance_api.dart';
import 'package:tks_nexa_attendance/features/attendance/data/platform_device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/data/secure_biometric_profile_store.dart';
import 'package:tks_nexa_attendance/features/attendance/data/secure_device_identity.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_verification_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

final mobileAttendanceServiceProvider = Provider<MobileAttendanceService>((
  ref,
) {
  final organization = ref.watch(organizationSessionProvider).value;
  final session = ref.watch(currentAuthSessionProvider);
  if (organization == null || session == null) {
    throw StateError('An authenticated tenant session is required.');
  }
  return MobileAttendanceApi(
    DioFactory.createTenantClient(
      ref.watch(appConfigProvider),
      organization.apiBaseUri,
    ),
    session.accessToken,
  );
});

final mobileAttendanceApiProvider = Provider<MobileAttendanceApi>((ref) {
  final organization = ref.watch(organizationSessionProvider).value;
  final session = ref.watch(currentAuthSessionProvider);
  if (organization == null || session == null) {
    throw StateError('An authenticated tenant session is required.');
  }
  return MobileAttendanceApi(
    DioFactory.createTenantClient(
      ref.watch(appConfigProvider),
      organization.apiBaseUri,
    ),
    session.accessToken,
  );
});

final faceVerificationServiceProvider = Provider<FaceVerificationService>(
  (ref) {
    final organization = ref.watch(organizationSessionProvider).value;
    final session = ref.watch(currentAuthSessionProvider);
    Dio? client;
    if (organization != null) {
      client = DioFactory.createTenantClient(
        ref.watch(appConfigProvider),
        organization.apiBaseUri,
      );
    }
    return createFaceVerificationService(
      photoDownloader: (url) async {
        try {
          final dio = client ?? Dio();
          final headers = <String, dynamic>{};
          if (session != null) {
            headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          final res = await dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: headers,
            ),
          );
          if (res.data != null) return Uint8List.fromList(res.data!);
          return null;
        } catch (_) {
          return null;
        }
      },
    );
  },
);

final deviceSecurityServiceProvider = Provider<DeviceSecurityService>(
  (ref) => const PlatformDeviceSecurityService(),
);

final attendanceChallengeProvider =
    FutureProvider.autoDispose<AttendanceChallenge>((ref) async {
      final organization = ref.watch(organizationSessionProvider).value;
      if (organization == null) throw StateError('Organization is required.');
      final deviceId = await SecureDeviceIdentity(
        ref.watch(secureStorageServiceProvider),
        organization.code,
      ).getOrCreate();
      final key = await ref.watch(deviceSecurityServiceProvider).getDeviceKey();
      if (key != null) {
        final package = await PackageInfo.fromPlatform();
        await ref
            .watch(mobileAttendanceServiceProvider)
            .registerDevice(
              deviceId: deviceId,
              key: key,
              appVersion: '${package.version}+${package.buildNumber}',
            );
      }
      return ref
          .watch(mobileAttendanceServiceProvider)
          .requestChallenge(deviceId: deviceId);
    });

final faceBiometricProfileProvider =
    AsyncNotifierProvider<FaceBiometricProfileController, FaceBiometricProfile>(
      FaceBiometricProfileController.new,
    );

final attendanceSubmissionProvider =
    AsyncNotifierProvider<
      AttendanceSubmissionController,
      AttendanceMarkResult?
    >(AttendanceSubmissionController.new);

class FaceBiometricProfileController
    extends AsyncNotifier<FaceBiometricProfile> {
  @override
  Future<FaceBiometricProfile> build() {
    ref.watch(currentAuthSessionProvider);
    ref.watch(organizationSessionProvider);
    return refresh();
  }

  Future<FaceBiometricProfile> refresh() async {
    final organization = ref.read(organizationSessionProvider).value;
    if (organization == null) throw StateError('Organization is required.');
    final store = SecureBiometricProfileStore(
      ref.read(secureStorageServiceProvider),
      organization.code,
    );
    try {
      final profile = await ref
          .read(mobileAttendanceServiceProvider)
          .fetchFaceProfile();
      await store.save(profile);
      return profile;
    } on AppFailure catch (error) {
      if (error.code == FailureCode.unauthorized ||
          error.code == FailureCode.invalidInput ||
          error.code == FailureCode.invalidResponse) {
        rethrow;
      }
      final cached = await store.read();
      if (cached != null) return cached;
      rethrow;
    }
  }
}

class AttendanceSubmissionController
    extends AsyncNotifier<AttendanceMarkResult?> {
  @override
  FutureOr<AttendanceMarkResult?> build() => null;

  Future<AttendanceMarkResult?> submit({
    required FaceCaptureEvidence capture,
    required LocationEvidence location,
  }) async {
    if (location.isMocked) {
      state = AsyncError(
        const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Mock location was reported by the device.',
          diagnosticCode: 'MOCK_LOCATION_REJECTED',
        ),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      FaceBiometricProfile profile;
      try {
        profile = await ref.refresh(faceBiometricProfileProvider.future);
      } catch (_) {
        profile = await ref.read(faceBiometricProfileProvider.future);
      }
      final verification = await ref
          .read(faceVerificationServiceProvider)
          .verify(capture: capture, enrolledProfile: profile);
      if (!verification.livenessPassed) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Liveness challenge failed. Please blink or smile at the camera.',
          diagnosticCode: 'LIVENESS_FAILED',
        );
      }
      if (!verification.matched) {
        throw AppFailure(
          code: FailureCode.invalidInput,
          message:
              'Facial similarity score (${(verification.similarity * 100).toStringAsFixed(1)}%) is below the required 70.0% matching threshold.',
          diagnosticCode: 'CONFIDENCE_BELOW_THRESHOLD',
        );
      }
      final organization = ref.read(organizationSessionProvider).value;
      if (organization == null) throw StateError('Organization is required.');
      final deviceId = await SecureDeviceIdentity(
        ref.read(secureStorageServiceProvider),
        organization.code,
      ).getOrCreate();
      final key = await ref.read(deviceSecurityServiceProvider).getDeviceKey();
      var challenge = await ref.read(attendanceChallengeProvider.future);
      if (challenge.isExpiredAt(DateTime.now().toUtc())) {
        challenge = await ref.refresh(attendanceChallengeProvider.future);
      }
      final capturedAt = DateTime.now().toUtc();
      final snapshotBytes = capture.croppedFaceBytes ?? capture.bytes;
      final snapshotBase64Payload =
          'data:image/jpeg;base64,${base64Encode(snapshotBytes)}';
      final unsignedRequest = AttendanceMarkRequest(
        verification: verification,
        location: location,
        deviceId: deviceId,
        deviceModel: key?.deviceModel,
        osVersion: key?.osVersion,
        platform: key?.platform,
        capturedAt: capturedAt,
        challengeId: challenge.id,
        snapshotBase64: snapshotBase64Payload,
      );
      final deviceEvidence = await ref
          .read(deviceSecurityServiceProvider)
          .createEvidence(
            canonicalPayload: unsignedRequest.canonicalPayload(challenge.nonce),
            integrityNonce: challenge.nonce,
            requireIntegrity: challenge.policy.requireAppIntegrity,
          );
      final config = ref.read(appConfigProvider);
      var integrityToken = deviceEvidence.integrityToken;
      if (challenge.policy.requireAppIntegrity && integrityToken == null) {
        if (config.allowMockSecurity || config.allowsLocalHttp) {
          integrityToken = 'development_mock_integrity_token';
        } else if (deviceEvidence.signature != null) {
          integrityToken = 'hardware_keystore_signature_verified';
        } else {
          throw const AppFailure(
            code: FailureCode.unavailable,
            message:
                'This organization requires native app integrity. Use the installed Android or iOS app for attendance.',
            diagnosticCode: 'NATIVE_APP_INTEGRITY_REQUIRED',
          );
        }
      }
      final result = await ref
          .read(mobileAttendanceServiceProvider)
          .markAttendance(
            AttendanceMarkRequest(
              verification: verification,
              location: location,
              deviceId: deviceId,
              deviceModel: key?.deviceModel,
              osVersion: key?.osVersion,
              platform: key?.platform,
              capturedAt: capturedAt,
              challengeId: challenge.id,
              deviceSignature: deviceEvidence.signature,
              integrityToken: integrityToken,
              snapshotBase64: snapshotBase64Payload,
            ),
          );
      await ref.read(localSelfieStorageProvider).saveSelfie(
            imageBytes: capture.bytes,
            date: capturedAt,
            type: result.type?.apiValue ?? 'check_in',
          );
      state = AsyncData(result);
      return result;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_time_service.dart';
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
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';
import 'package:tks_nexa_attendance/features/attendance/application/offline_punch_sync_service.dart';

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
        try {
          await ref
              .watch(mobileAttendanceServiceProvider)
              .registerDevice(
                deviceId: deviceId,
                key: key,
                appVersion: '${package.version}+${package.buildNumber}',
              );
        } catch (_) {}
      }
      try {
        final challenge = await ref
            .watch(mobileAttendanceServiceProvider)
            .requestChallenge(deviceId: deviceId);
        try {
          await ref.read(secureStorageServiceProvider).write(
                'offline_attendance_enabled',
                challenge.policy.offlineAttendanceEnabled ? 'true' : 'false',
              );
        } catch (_) {}
        return challenge;
      } catch (_) {
        final now = DateTime.now().toUtc();
        bool isOfflineAllowed = false;
        try {
          final cached = await ref
              .read(secureStorageServiceProvider)
              .read('offline_attendance_enabled');
          isOfflineAllowed = cached == 'true';
        } catch (_) {}
        return AttendanceChallenge(
          id: 'offline_${now.millisecondsSinceEpoch}',
          nonce: 'offline_nonce_${now.millisecondsSinceEpoch}',
          serverTimestamp: now,
          expiresAt: now.add(const Duration(hours: 24)),
          policy: AttendanceChallengePolicy(
            polygonGeofenceEnabled: false,
            requireAppIntegrity: false,
            cameraVerificationEnabled: false,
            offlineAttendanceEnabled: isOfflineAllowed,
          ),
        );
      }
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

    final securityService = ref.read(deviceSecurityServiceProvider);
    final securityStatus = await securityService.checkDeviceSecurity();
    final config = ref.read(appConfigProvider);
    if (securityStatus.isTampered && !config.allowMockSecurity) {
      state = AsyncError(
        const AppFailure(
          code: FailureCode.invalidInput,
          message:
              'Untrusted device environment detected. Rooted or modified operating systems are prohibited for attendance.',
          diagnosticCode: 'DEVICE_TAMPERING_DETECTED',
        ),
        StackTrace.current,
      );
      return null;
    }

    final wifiDetails = await securityService.getWifiDetails();
    final resolvedLocation = location.copyWith(
      wifiBssid: wifiDetails.bssid,
      wifiSsid: wifiDetails.ssid,
      wifiGatewayIp: wifiDetails.gatewayIp,
    );

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
        final simPct = verification.similarity != null
            ? '${(verification.similarity! * 100).toStringAsFixed(1)}%'
            : '0.0%';
        throw AppFailure(
          code: FailureCode.invalidInput,
          message:
              'Facial similarity score ($simPct) is below the required ${(profile.matchThreshold * 100).toStringAsFixed(1)}% matching threshold.',
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
        location: resolvedLocation,
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
      final markRequest = AttendanceMarkRequest(
        verification: verification,
        location: resolvedLocation,
        deviceId: deviceId,
        deviceModel: key?.deviceModel,
        osVersion: key?.osVersion,
        platform: key?.platform,
        capturedAt: capturedAt,
        challengeId: challenge.id,
        deviceSignature: deviceEvidence.signature,
        integrityToken: integrityToken,
        snapshotBase64: snapshotBase64Payload,
      );

      AttendanceMarkResult result;
      final trustedTimeService = ref.read(trustedTimeServiceProvider);
      final clockVerdict = trustedTimeService.checkClockIntegrity(capturedAt);

      Future<AttendanceMarkResult> createOfflineResult() async {
        if (!challenge.policy.offlineAttendanceEnabled) {
          throw const AppFailure(
            code: FailureCode.invalidInput,
            message:
                'Offline attendance is disabled by your organization policy. Please connect to the internet to record attendance.',
            diagnosticCode: 'OFFLINE_ATTENDANCE_DISABLED',
          );
        }
        final offlineId = 'offline_${capturedAt.toUtc().millisecondsSinceEpoch}';
        final payloadMap = markRequest.toJson();
        final hash = OfflinePunchItem.generatePayloadHash(
          id: offlineId,
          capturedAt: capturedAt,
          payload: payloadMap,
        );
        final timeIntegrity = await securityService.getDeviceTimeIntegrity();
        final offlineItem = OfflinePunchItem(
          id: offlineId,
          capturedAt: capturedAt,
          requestPayload: payloadMap,
          status: OfflinePunchStatus.pending,
          createdAt: DateTime.now().toUtc(),
          payloadHash: hash,
          clockSkewSeconds: clockVerdict.clockSkewSeconds,
          isTimeManipulated: clockVerdict.isTimeManipulated || (timeIntegrity != null && !timeIntegrity.isAutoTimeEnabled),
          isMockLocation: resolvedLocation.isMocked,
          elapsedRealtimeMsAtPunch: timeIntegrity?.elapsedRealtimeMs,
          isAutoTime: timeIntegrity?.isAutoTimeEnabled ?? true,
        );
        await ref.read(offlinePunchOutboxProvider).enqueue(offlineItem);
        unawaited(ref.read(offlinePunchSyncProvider.notifier).refreshPendingCount());
        return AttendanceMarkResult(
          message: 'Punch secured offline. Facial features and location recorded and will be verified once online.',
          attendanceId: offlineId,
          recordedAt: capturedAt,
          type: null,
          similarityScore: verification.similarity != null ? verification.similarity! * 100 : null,
          trustScore: 90,
          trustLevel: 'Offline Secured',
          isOffline: true,
        );
      }

      try {
        result = await ref
            .read(mobileAttendanceServiceProvider)
            .markAttendance(markRequest);
        if (result.recordedAt != null) {
          trustedTimeService.recordServerAnchor(result.recordedAt!);
        }
      } on AppFailure catch (failure) {
        if (failure.code == FailureCode.unavailable) {
          result = await createOfflineResult();
        } else {
          rethrow;
        }
      } catch (e) {
        result = await createOfflineResult();
      }
      final resolvedResult = (result.similarityScore != null && result.similarityScore! > 0)
          ? result
          : AttendanceMarkResult(
              message: result.message,
              attendanceId: result.attendanceId,
              recordedAt: result.recordedAt,
              type: result.type,
              similarityScore: verification.similarity != null ? verification.similarity! * 100 : null,
              trustScore: result.trustScore,
              trustLevel: result.trustLevel,
              cameraCorroboration: result.cameraCorroboration,
              isOffline: result.isOffline,
            );
      await ref.read(localSelfieStorageProvider).saveSelfie(
            imageBytes: capture.bytes,
            date: capturedAt,
            type: resolvedResult.type?.apiValue ?? 'check_in',
            id: resolvedResult.attendanceId,
            verificationCode: challenge.id,
          );
      state = AsyncData(resolvedResult);
      return resolvedResult;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_time_service.dart';
import 'package:tks_nexa_attendance/features/attendance/application/offline_punch_sync_service.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';

class MockMobileAttendanceService implements MobileAttendanceService {
  final List<Map<String, dynamic>> submittedPayloads = [];
  bool simulateOffline = false;
  bool simulateBusinessError = false;
  bool simulateSimilarityMismatch = false;

  @override
  Future<AttendanceMarkResult> submitRawPunchPayload(Map<String, dynamic> payload) async {
    if (simulateOffline) {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message: 'Network offline.',
        diagnosticCode: 'ATTENDANCE_API_UNAVAILABLE',
      );
    }
    if (simulateBusinessError) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Punch already marked for this shift.',
        diagnosticCode: 'ALREADY_MARKED',
      );
    }
    if (simulateSimilarityMismatch) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Facial similarity score (52.4%) is below the required 75.0% matching threshold.',
        diagnosticCode: 'CONFIDENCE_BELOW_THRESHOLD',
      );
    }
    submittedPayloads.add(payload);
    return AttendanceMarkResult(
      message: 'Attendance recorded successfully.',
      attendanceId: 'server_punch_${submittedPayloads.length}',
      recordedAt: DateTime.now().toUtc(),
      type: AttendanceType.checkIn,
    );
  }

  @override
  Future<AttendanceMarkResult> markAttendance(AttendanceMarkRequest request) =>
      submitRawPunchPayload(request.toJson());

  @override
  Future<FaceBiometricProfile> fetchFaceProfile() async =>
      FaceBiometricProfile(
        employeeId: 'EMP001',
        embedding: List.filled(512, 0.1),
        matchThreshold: 0.75,
        modelVersion: 'v1.0',
        livenessRequired: false,
      );

  @override
  Future<AttendanceChallenge> requestChallenge({required String deviceId}) async {
    final now = DateTime.now().toUtc();
    return AttendanceChallenge(
      id: 'challenge_123',
      nonce: 'nonce_123',
      serverTimestamp: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      policy: const AttendanceChallengePolicy(
        polygonGeofenceEnabled: false,
        requireAppIntegrity: false,
        cameraVerificationEnabled: false,
      ),
    );
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required DeviceKeyDetails key,
    required String appVersion,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FileOfflinePunchOutbox outbox;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('offline_punch_test_');
    outbox = FileOfflinePunchOutbox(baseDirectory: tempDir);
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('OfflinePunchItem Model Tests', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.utc(2026, 10, 20, 10, 30);
      final item = OfflinePunchItem(
        id: 'offline_123456789',
        capturedAt: now,
        requestPayload: {
          'latitude': 34.1989,
          'longitude': 72.0404,
          'challenge_id': 'challenge_123',
        },
        status: OfflinePunchStatus.pending,
        createdAt: now,
        syncAttempts: 1,
        lastError: 'Temporary network failure',
      );

      final json = item.toJson();
      final restored = OfflinePunchItem.fromJson(json);

      expect(restored.id, equals('offline_123456789'));
      expect(restored.capturedAt, equals(now));
      expect(restored.status, equals(OfflinePunchStatus.pending));
      expect(restored.syncAttempts, equals(1));
      expect(restored.lastError, equals('Temporary network failure'));
      expect(restored.requestPayload['latitude'], equals(34.1989));
    });
  });

  group('FileOfflinePunchOutbox CRUD Tests', () {
    test('enqueues, retrieves pending items, and removes after sync', () async {
      expect(await outbox.getPendingCount(), equals(0));

      final now = DateTime.utc(2026, 10, 20, 8, 0);
      final item1 = OfflinePunchItem(
        id: 'punch_001',
        capturedAt: now,
        requestPayload: {'id': 1},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      );
      final item2 = OfflinePunchItem(
        id: 'punch_002',
        capturedAt: now.add(const Duration(minutes: 1)),
        requestPayload: {'id': 2},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      );

      await outbox.enqueue(item1);
      await outbox.enqueue(item2);

      expect(await outbox.getPendingCount(), equals(2));

      final pending = await outbox.getPending();
      expect(pending.length, equals(2));
      expect(pending.first.id, equals('punch_001'));
      expect(pending.last.id, equals('punch_002'));

      // Remove one
      await outbox.remove('punch_001');
      expect(await outbox.getPendingCount(), equals(1));

      final remaining = await outbox.getPending();
      expect(remaining.first.id, equals('punch_002'));

      // Clear all
      await outbox.clear();
      expect(await outbox.getPendingCount(), equals(0));
    });
  });

  group('OfflinePunchSyncController Tests', () {
    late MockMobileAttendanceService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockMobileAttendanceService();
      container = ProviderContainer(
        overrides: [
          offlinePunchOutboxProvider.overrideWithValue(outbox),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('syncAll uploads pending punches and empties outbox', () async {
      final now = DateTime.utc(2026, 10, 20, 8, 30);
      await outbox.enqueue(OfflinePunchItem(
        id: 'sync_test_1',
        capturedAt: now,
        requestPayload: {'payload_key': 'punch_1'},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      ));
      await outbox.enqueue(OfflinePunchItem(
        id: 'sync_test_2',
        capturedAt: now.add(const Duration(minutes: 5)),
        requestPayload: {'payload_key': 'punch_2'},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      expect(result.syncedCount, equals(2));
      expect(result.failedCount, equals(0));
      expect(mockService.submittedPayloads.length, equals(2));
      expect(mockService.submittedPayloads[0]['payload_key'], equals('punch_1'));
      expect(mockService.submittedPayloads[1]['payload_key'], equals('punch_2'));

      // Outbox should now be empty
      expect(await outbox.getPendingCount(), equals(0));
    });

    test('syncAll pauses when network is unavailable without dropping punches', () async {
      mockService.simulateOffline = true;

      final now = DateTime.utc(2026, 10, 20, 9, 0);
      await outbox.enqueue(OfflinePunchItem(
        id: 'offline_stay_1',
        capturedAt: now,
        requestPayload: {'payload_key': 'offline_1'},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      expect(result.syncedCount, equals(0));
      expect(result.failedCount, equals(0));
      expect(result.errors, contains('Network unavailable. Remaining punches queued.'));

      // Outbox still holds the punch
      expect(await outbox.getPendingCount(), equals(1));
    });

    test('syncAll flags business errors and retains error diagnostic', () async {
      mockService.simulateBusinessError = true;

      final now = DateTime.utc(2026, 10, 20, 9, 30);
      await outbox.enqueue(OfflinePunchItem(
        id: 'business_fail_1',
        capturedAt: now,
        requestPayload: {'payload_key': 'fail_1'},
        status: OfflinePunchStatus.pending,
        createdAt: now,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      expect(result.syncedCount, equals(0));
      expect(result.failedCount, equals(1));
      expect(result.errors, contains('Punch already marked for this shift.'));

      final items = await outbox.getAll();
      expect(items.first.status, equals(OfflinePunchStatus.failed));
      expect(items.first.lastError, equals('Punch already marked for this shift.'));
    });

    test('syncAll marks punch as rejected when similarity is below threshold', () async {
      mockService.simulateSimilarityMismatch = true;

      final now = DateTime.utc(2026, 10, 20, 10, 0);
      await outbox.enqueue(OfflinePunchItem(
        id: 'similarity_fail_1',
        capturedAt: now,
        requestPayload: {
          'similarity_score': 0.524,
          'match_threshold': 0.75,
        },
        status: OfflinePunchStatus.pending,
        createdAt: now,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      expect(result.syncedCount, equals(0));
      expect(result.rejectedCount, equals(1));
      expect(result.errors, contains(contains('below the required 75.0% matching threshold')));

      final all = await outbox.getAll();
      final rejectedItem = all.firstWhere((i) => i.id == 'similarity_fail_1');
      expect(rejectedItem.status, equals(OfflinePunchStatus.rejected));
      expect(rejectedItem.isRejected, isTrue);
      expect(rejectedItem.lastError, contains('below the required 75.0% matching threshold'));

      // Rejected items are excluded from pendingCount
      final state = container.read(offlinePunchSyncProvider).value!;
      expect(state.pendingCount, equals(0));
      expect(state.rejectedCount, equals(1));
    });

    test('fromJson auto-migrates legacy punches with similarity error to rejected status', () {
      final legacyJson = {
        'id': 'legacy_stuck_punch',
        'captured_at': '2026-10-20T10:00:00.000Z',
        'request_payload': {'similarity_score': 0.52},
        'status': 'failed',
        'created_at': '2026-10-20T10:00:00.000Z',
        'sync_attempts': 3,
        'last_error': 'Facial similarity score is below the required 75% threshold',
      };

      final migrated = OfflinePunchItem.fromJson(legacyJson);
      expect(migrated.status, equals(OfflinePunchStatus.rejected));
      expect(migrated.isRejected, isTrue);
    });

    test('retryPunch and removePunch operate properly from controller', () async {
      final now = DateTime.utc(2026, 10, 20, 11, 0);
      await outbox.enqueue(OfflinePunchItem(
        id: 'punch_to_remove',
        capturedAt: now,
        requestPayload: {'key': 'val'},
        status: OfflinePunchStatus.rejected,
        createdAt: now,
        lastError: 'Similarity mismatch',
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      await controller.refresh();

      expect(container.read(offlinePunchSyncProvider).value!.rejectedCount, equals(1));

      // Remove it
      await controller.removePunch('punch_to_remove');
      expect(container.read(offlinePunchSyncProvider).value!.rejectedCount, equals(0));
      expect(await outbox.getAll(), isEmpty);
    });

    test('syncAll injects complete date/time metadata preserving original capture date', () async {
      // Offline punch captured at 8:45 AM yesterday
      final yesterdayCaptured = DateTime(2026, 10, 21, 8, 45, 30);
      final payload = {
        'challenge_id': 'ch_yesterday',
        'device_id': 'device_test_1',
        'latitude': 34.1989,
        'longitude': 72.0404,
      };
      final hash = OfflinePunchItem.generatePayloadHash(
        id: 'punch_yesterday',
        capturedAt: yesterdayCaptured,
        payload: payload,
      );

      await outbox.enqueue(OfflinePunchItem(
        id: 'punch_yesterday',
        capturedAt: yesterdayCaptured,
        requestPayload: payload,
        status: OfflinePunchStatus.pending,
        createdAt: yesterdayCaptured,
        payloadHash: hash,
        clockSkewSeconds: 0,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      expect(result.syncedCount, equals(1));
      expect(mockService.submittedPayloads.length, equals(1));

      final submitted = mockService.submittedPayloads.first;
      expect(submitted['is_offline'], isTrue);
      expect(submitted['offline_sync'], isTrue);
      // Punch date MUST be preserved as yesterday's date
      expect(submitted['attendance_date'], equals('2026-10-21'));
      expect(submitted['date'], equals('2026-10-21'));
      expect(submitted['punch_time'], equals('08:45:30'));
      expect(submitted['time'], equals('08:45:30'));
      expect(submitted['recorded_at'], equals(yesterdayCaptured.toUtc().toIso8601String()));
      expect(submitted['offline_captured_at'], equals(yesterdayCaptured.toUtc().toIso8601String()));
      expect(submitted['synced_at'], isNotNull);
      expect(submitted['sync_delay_seconds'], isNotNull);
    });

    test('tampered payload fails integrity verification and is rejected from sync', () async {
      final now = DateTime.utc(2026, 10, 22, 9, 0);
      final originalPayload = {
        'challenge_id': 'ch_secure',
        'latitude': 34.1989,
        'longitude': 72.0404,
      };
      final hash = OfflinePunchItem.generatePayloadHash(
        id: 'tamper_test_1',
        capturedAt: now,
        payload: originalPayload,
      );

      // Maliciously modify the payload (e.g. change GPS coordinates on device)
      final tamperedPayload = {
        'challenge_id': 'ch_secure',
        'latitude': 40.7128, // Altered
        'longitude': -74.0060, // Altered
      };

      await outbox.enqueue(OfflinePunchItem(
        id: 'tamper_test_1',
        capturedAt: now,
        requestPayload: tamperedPayload,
        status: OfflinePunchStatus.pending,
        createdAt: now,
        payloadHash: hash,
      ));

      final controller = container.read(offlinePunchSyncProvider.notifier);
      final result = await controller.syncAll(overrideService: mockService);

      // The tampered punch should NOT be synced to server
      expect(result.syncedCount, equals(0));
      expect(mockService.submittedPayloads, isEmpty);

      final all = await outbox.getAll();
      final item = all.firstWhere((i) => i.id == 'tamper_test_1');
      expect(item.status, equals(OfflinePunchStatus.rejected));
      expect(item.lastError, contains('altered or tampered'));
      expect(await outbox.getPendingCount(), equals(0));
    });
  });

  group('TrustedTimeService Tests', () {
    test('detects clock skew when device clock rolls backward', () {
      final service = TrustedTimeService();
      final serverNow = DateTime.utc(2026, 10, 22, 10, 0);
      service.recordServerAnchor(serverNow);

      // Emulate device clock rolled back to 8:30 AM (90 minutes behind)
      final rolledBackDeviceTime = DateTime.utc(2026, 10, 22, 8, 30);
      final verdict = service.checkClockIntegrity(rolledBackDeviceTime);

      expect(verdict.isTimeManipulated, isTrue);
      expect(verdict.clockSkewSeconds, lessThan(-5000));
      expect(verdict.reason, contains('Device clock appears to be rolled backwards'));
    });

    test('accepts device time within acceptable drift threshold', () {
      final service = TrustedTimeService();
      final serverNow = DateTime.now().toUtc();
      service.recordServerAnchor(serverNow);

      // Normal clock with 30s drift
      final normalTime = serverNow.add(const Duration(seconds: 30));
      final verdict = service.checkClockIntegrity(normalTime);

      expect(verdict.isTimeManipulated, isFalse);
      expect(verdict.clockSkewSeconds.abs(), lessThanOrEqualTo(180));
    });
  });
}

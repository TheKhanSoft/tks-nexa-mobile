import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/offline_security_token_service.dart';
import 'package:tks_nexa_attendance/core/security/trusted_time_service.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';
import 'package:tks_nexa_attendance/features/notifications/application/notification_inbox_service.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

class SyncResult {
  const SyncResult({
    required this.totalProcessed,
    required this.syncedCount,
    required this.failedCount,
    this.rejectedCount = 0,
    this.errors = const [],
  });

  final int totalProcessed;
  final int syncedCount;
  final int failedCount;
  final int rejectedCount;
  final List<String> errors;

  bool get hasFailures => failedCount > 0 || rejectedCount > 0;
  bool get hasSuccess => syncedCount > 0;
}

class OfflineSyncState {
  const OfflineSyncState({
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.items = const [],
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastResult,
  });

  final int pendingCount;
  final int rejectedCount;
  final List<OfflinePunchItem> items;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final SyncResult? lastResult;

  int get totalCount => items.length;
  bool get hasPending => pendingCount > 0;
  bool get hasRejected => rejectedCount > 0;

  OfflineSyncState copyWith({
    int? pendingCount,
    int? rejectedCount,
    List<OfflinePunchItem>? items,
    bool? isSyncing,
    DateTime? lastSyncAt,
    SyncResult? lastResult,
  }) {
    return OfflineSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
      items: items ?? this.items,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class OfflinePunchSyncController extends AsyncNotifier<OfflineSyncState> {
  OfflinePunchOutbox get _outbox => ref.read(offlinePunchOutboxProvider);
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  Future<OfflineSyncState> build() async {
    final outbox = ref.watch(offlinePunchOutboxProvider);
    final all = await outbox.getAll();
    final pending = all.where((i) => i.isPending || i.isFailed).length;
    final rejected = all.where((i) => i.isRejected).length;

    // Automatically sync queued offline punches as soon as network reconnects
    try {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        final isConnected = results.any((r) => r != ConnectivityResult.none);
        if (isConnected) {
          _triggerAutoSyncIfPending();
        }
      });
    } catch (_) {
      // In headless unit test environments without platform channels, ignore
    }

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });

    return OfflineSyncState(
      pendingCount: pending,
      rejectedCount: rejected,
      items: all,
    );
  }

  void _triggerAutoSyncIfPending() {
    final current = state.value;
    if (current != null && current.pendingCount > 0 && !current.isSyncing) {
      debugPrint('[OfflineSync] Network connected. Auto-syncing ${current.pendingCount} pending punches...');
      unawaited(syncAll());
    }
  }

  Future<void> refresh() async {
    final all = await _outbox.getAll();
    final pending = all.where((i) => i.isPending || i.isFailed).length;
    final rejected = all.where((i) => i.isRejected).length;
    state = AsyncData(
      (state.value ?? const OfflineSyncState()).copyWith(
        pendingCount: pending,
        rejectedCount: rejected,
        items: all,
      ),
    );
  }

  Future<void> refreshPendingCount() async {
    await refresh();
    _triggerAutoSyncIfPending();
  }

  Future<void> removePunch(String id) async {
    await _outbox.remove(id);
    await refresh();
  }

  Future<void> clearRejected() async {
    await _outbox.clearRejected();
    await refresh();
  }

  Future<void> clearAll() async {
    await _outbox.clear();
    await refresh();
  }

  Future<void> retryPunch(String id) async {
    final all = await _outbox.getAll();
    final item = all.where((i) => i.id == id).firstOrNull;
    if (item == null) return;

    final updated = item.copyWith(
      status: OfflinePunchStatus.pending,
      syncAttempts: 0,
      lastError: null,
    );
    await _outbox.update(updated);
    await refresh();
    await syncAll();
  }

  Future<SyncResult> syncAll({
    MobileAttendanceService? overrideService,
  }) async {
    final current = state.value ?? const OfflineSyncState();
    if (current.isSyncing) {
      return current.lastResult ??
          const SyncResult(totalProcessed: 0, syncedCount: 0, failedCount: 0);
    }

    state = AsyncData(current.copyWith(isSyncing: true));

    final pending = await _outbox.getPending();
    if (pending.isEmpty) {
      final all = await _outbox.getAll();
      final rejected = all.where((i) => i.isRejected).length;
      final res = const SyncResult(totalProcessed: 0, syncedCount: 0, failedCount: 0);
      state = AsyncData(
        current.copyWith(
          isSyncing: false,
          pendingCount: 0,
          rejectedCount: rejected,
          items: all,
          lastSyncAt: DateTime.now(),
          lastResult: res,
        ),
      );
      return res;
    }

    int synced = 0;
    int failed = 0;
    int rejected = 0;
    final errors = <String>[];
    MobileAttendanceService? service = overrideService;

    if (service == null) {
      try {
        service = ref.read(mobileAttendanceServiceProvider);
      } catch (_) {
        state = AsyncData(current.copyWith(isSyncing: false));
        return const SyncResult(totalProcessed: 0, syncedCount: 0, failedCount: 0);
      }
    }

    final activeService = service;
    if (activeService == null) {
      state = AsyncData(current.copyWith(isSyncing: false));
      return const SyncResult(totalProcessed: 0, syncedCount: 0, failedCount: 0);
    }

    for (final item in pending) {
      if (!item.verifyIntegrity()) {
        final updated = item.copyWith(
          status: OfflinePunchStatus.rejected,
          lastError: 'Integrity check failed: punch payload was tampered with.',
        );
        await _outbox.update(updated);
        rejected++;
        continue;
      }

      try {
        final payload = Map<String, dynamic>.from(item.requestPayload);
        final capturedLocal = item.capturedAt.toLocal();
        final capturedUtc = item.capturedAt.toUtc();
        final nowUtc = DateTime.now().toUtc();
        final dateStr =
            '${capturedLocal.year}-${capturedLocal.month.toString().padLeft(2, '0')}-${capturedLocal.day.toString().padLeft(2, '0')}';
        final timeStr =
            '${capturedLocal.hour.toString().padLeft(2, '0')}:${capturedLocal.minute.toString().padLeft(2, '0')}:${capturedLocal.second.toString().padLeft(2, '0')}';

        // Provide exhaustive date/time keys so backend cannot misplace the offline punch date
        payload['is_offline'] = true;
        payload['offline_sync'] = true;
        payload['offline_captured_at'] = capturedUtc.toIso8601String();
        payload['recorded_at'] = capturedUtc.toIso8601String();
        payload['timestamp'] = capturedUtc.toIso8601String();
        payload['captured_at'] = capturedUtc.toIso8601String();
        payload['client_timestamp'] = capturedUtc.toIso8601String();
        payload['attendance_date'] = dateStr;
        payload['date'] = dateStr;
        payload['attendance_time'] = timeStr;
        payload['time'] = timeStr;
        payload['punch_time'] = timeStr;
        payload['punch_datetime'] = capturedLocal.toIso8601String();
        payload['synced_at'] = nowUtc.toIso8601String();
        payload['sync_delay_seconds'] = nowUtc.difference(capturedUtc).inSeconds;

        if (item.clockSkewSeconds != null) {
          payload['clock_skew_seconds'] = item.clockSkewSeconds;
        }
        if (item.isTimeManipulated) {
          payload['is_time_manipulated'] = true;
          payload['time_tamper_warning'] =
              'Device clock mismatch of ${item.clockSkewSeconds}s detected during offline capture';
        }
        if (item.isMockLocation) {
          payload['is_mocked'] = true;
          payload['mock_location_warning'] =
              'Mock GPS location provider detected during offline capture';
        }

        // Generate encrypted, HMAC-signed anti-tampering security token
        String? secret;
        try {
          secret = ref.read(appConfigProvider).mobileApiSecret;
        } catch (_) {}

        DeviceTimeIntegrity? currentIntegrity;
        try {
          final secService = ref.read(deviceSecurityServiceProvider);
          currentIntegrity = await secService.getDeviceTimeIntegrity();
        } catch (_) {}

        final syncElapsedMs = currentIntegrity?.elapsedRealtimeMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
        final punchElapsedMs = item.elapsedRealtimeMsAtPunch ?? item.capturedAt.toUtc().millisecondsSinceEpoch;
        final monotonicDeltaMs = (currentIntegrity != null && item.elapsedRealtimeMsAtPunch != null)
            ? (syncElapsedMs - punchElapsedMs)
            : nowUtc.difference(capturedUtc).inMilliseconds;

        DateTime? anchor;
        try {
          anchor = ref.read(trustedTimeServiceProvider).lastServerAnchorUtc;
        } catch (_) {}

        final tokenPayload = {
          'punch_id': item.id,
          'device_id': payload['device_id'] ?? '',
          'captured_at': capturedUtc.toIso8601String(),
          'device_wall_time_ms': item.capturedAt.millisecondsSinceEpoch,
          'punch_elapsed_realtime_ms': punchElapsedMs,
          'sync_elapsed_realtime_ms': syncElapsedMs,
          'monotonic_elapsed_ms': monotonicDeltaMs,
          'is_auto_time': item.isAutoTime,
          'last_server_anchor_utc': anchor?.toIso8601String(),
          'clock_skew_seconds': item.clockSkewSeconds ?? 0,
          'is_time_manipulated': item.isTimeManipulated,
          'payload_hash': item.payloadHash ?? '',
          'created_at_epoch': nowUtc.millisecondsSinceEpoch ~/ 1000,
        };

        if (secret != null && secret.isNotEmpty) {
          final offlineSecurityToken = OfflineSecurityTokenService.createToken(
            payload: tokenPayload,
            secret: secret,
          );
          payload['offline_security_token'] = offlineSecurityToken;
          payload['offline_sync_token'] = offlineSecurityToken;
        }

        await activeService.submitRawPunchPayload(payload);
        await _outbox.remove(item.id);
        synced++;
      } on AppFailure catch (failure) {
        if (failure.code == FailureCode.unavailable) {
          // Network is still unavailable: pause and resume later
          errors.add('Network unavailable. Remaining punches queued.');
          break;
        } else {
          // Unrecoverable, validation, or biometric mismatch failure
          final msg = failure.message.toLowerCase();
          final isMismatch = msg.contains('similarity') ||
              msg.contains('threshold') ||
              msg.contains('mismatch') ||
              msg.contains('below') ||
              msg.contains('unapproved') ||
              msg.contains('rejected') ||
              failure.diagnosticCode == 'CONFIDENCE_BELOW_THRESHOLD' ||
              failure.diagnosticCode == 'LIVENESS_FAILED';

          if (isMismatch) {
            rejected++;
          } else {
            failed++;
          }
          errors.add(failure.message);

          final updated = item.copyWith(
            status: isMismatch ? OfflinePunchStatus.rejected : OfflinePunchStatus.failed,
            syncAttempts: item.syncAttempts + 1,
            lastError: failure.message,
          );
          await _outbox.update(updated);

          if (isMismatch) {
            try {
              ref.read(notificationInboxProvider.notifier).addNotification(
                    title: 'Offline Punch Rejected',
                    body: 'Your offline punch could not be uploaded: ${failure.message}',
                    category: NotificationCategory.security,
                  );
            } catch (_) {}
          }
        }
      } catch (e) {
        errors.add(e.toString());
        break;
      }
    }

    if (synced > 0) {
      ref.invalidate(attendanceHistoryResponseProvider);
      ref.invalidate(mobilePunchLogsProvider);
      try {
        ref.read(notificationInboxProvider.notifier).addNotification(
          title: 'Offline Attendance Synced',
          body: 'Successfully synced $synced offline attendance punch${synced > 1 ? 'es' : ''}.',
          category: NotificationCategory.system,
        );
      } catch (_) {}
    }

    final allAfter = await _outbox.getAll();
    final remainingPending = allAfter.where((i) => i.isPending || i.isFailed).length;
    final remainingRejected = allAfter.where((i) => i.isRejected).length;

    final result = SyncResult(
      totalProcessed: synced + failed + rejected,
      syncedCount: synced,
      failedCount: failed,
      rejectedCount: rejected,
      errors: errors,
    );

    state = AsyncData(
      OfflineSyncState(
        pendingCount: remainingPending,
        rejectedCount: remainingRejected,
        items: allAfter,
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastResult: result,
      ),
    );

    return result;
  }
}

final offlinePunchSyncProvider =
    AsyncNotifierProvider<OfflinePunchSyncController, OfflineSyncState>(
  OfflinePunchSyncController.new,
);

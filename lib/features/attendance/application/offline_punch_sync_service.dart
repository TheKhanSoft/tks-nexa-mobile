import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';

class SyncResult {
  const SyncResult({
    required this.totalProcessed,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });

  final int totalProcessed;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  bool get hasFailures => failedCount > 0;
  bool get hasSuccess => syncedCount > 0;
}

class OfflineSyncState {
  const OfflineSyncState({
    this.pendingCount = 0,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastResult,
  });

  final int pendingCount;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final SyncResult? lastResult;

  OfflineSyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncAt,
    SyncResult? lastResult,
  }) {
    return OfflineSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class OfflinePunchSyncController extends AsyncNotifier<OfflineSyncState> {
  OfflinePunchOutbox get _outbox => ref.read(offlinePunchOutboxProvider);

  @override
  Future<OfflineSyncState> build() async {
    final count = await ref.watch(offlinePunchOutboxProvider).getPendingCount();
    return OfflineSyncState(pendingCount: count);
  }

  Future<void> refreshPendingCount() async {
    final count = await _outbox.getPendingCount();
    state = AsyncData(
      (state.value ?? const OfflineSyncState()).copyWith(pendingCount: count),
    );
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
      final res = const SyncResult(totalProcessed: 0, syncedCount: 0, failedCount: 0);
      state = AsyncData(
        current.copyWith(
          isSyncing: false,
          pendingCount: 0,
          lastSyncAt: DateTime.now(),
          lastResult: res,
        ),
      );
      return res;
    }

    int synced = 0;
    int failed = 0;
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
      try {
        await activeService.submitRawPunchPayload(item.requestPayload);
        await _outbox.remove(item.id);
        synced++;
      } on AppFailure catch (failure) {
        if (failure.code == FailureCode.unavailable) {
          // Network is still unavailable: pause and resume later
          errors.add('Network unavailable. Remaining punches queued.');
          break;
        } else {
          // Unrecoverable or validation failure
          failed++;
          errors.add(failure.message);
          final updated = item.copyWith(
            status: OfflinePunchStatus.failed,
            syncAttempts: item.syncAttempts + 1,
            lastError: failure.message,
          );
          await _outbox.update(updated);
        }
      } catch (e) {
        errors.add(e.toString());
        break;
      }
    }

    if (synced > 0) {
      ref.invalidate(attendanceHistoryResponseProvider);
      ref.invalidate(mobilePunchLogsProvider);
    }

    final remaining = await _outbox.getPendingCount();
    final result = SyncResult(
      totalProcessed: synced + failed,
      syncedCount: synced,
      failedCount: failed,
      errors: errors,
    );

    state = AsyncData(
      OfflineSyncState(
        pendingCount: remaining,
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

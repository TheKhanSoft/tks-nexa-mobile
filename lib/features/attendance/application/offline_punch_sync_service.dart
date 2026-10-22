import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';
import 'package:tks_nexa_attendance/features/notifications/application/notification_inbox_service.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';

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

  @override
  Future<OfflineSyncState> build() async {
    final outbox = ref.watch(offlinePunchOutboxProvider);
    final all = await outbox.getAll();
    final pending = all.where((i) => i.isPending || i.isFailed).length;
    final rejected = all.where((i) => i.isRejected).length;
    return OfflineSyncState(
      pendingCount: pending,
      rejectedCount: rejected,
      items: all,
    );
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

  Future<void> refreshPendingCount() => refresh();

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

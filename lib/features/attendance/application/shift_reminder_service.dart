import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/local_notification_service.dart';
import 'package:tks_nexa_attendance/features/notifications/application/notification_inbox_service.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

class ShiftNotificationPreferences {
  const ShiftNotificationPreferences({
    this.shiftRemindersEnabled = true,
    this.shiftEndRemindersEnabled = true,
    this.missedAttendanceRemindersEnabled = true,
    this.leadTimeMinutes = 15,
    this.scheduleChangesEnabled = true,
    this.securityAlertsEnabled = true,
  });

  final bool shiftRemindersEnabled;
  final bool shiftEndRemindersEnabled;
  final bool missedAttendanceRemindersEnabled;
  final int leadTimeMinutes;
  final bool scheduleChangesEnabled;
  final bool securityAlertsEnabled;

  ShiftNotificationPreferences copyWith({
    bool? shiftRemindersEnabled,
    bool? shiftEndRemindersEnabled,
    bool? missedAttendanceRemindersEnabled,
    int? leadTimeMinutes,
    bool? scheduleChangesEnabled,
    bool? securityAlertsEnabled,
  }) {
    return ShiftNotificationPreferences(
      shiftRemindersEnabled: shiftRemindersEnabled ?? this.shiftRemindersEnabled,
      shiftEndRemindersEnabled: shiftEndRemindersEnabled ?? this.shiftEndRemindersEnabled,
      missedAttendanceRemindersEnabled: missedAttendanceRemindersEnabled ?? this.missedAttendanceRemindersEnabled,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
      scheduleChangesEnabled: scheduleChangesEnabled ?? this.scheduleChangesEnabled,
      securityAlertsEnabled: securityAlertsEnabled ?? this.securityAlertsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftNotificationPreferences &&
          runtimeType == other.runtimeType &&
          shiftRemindersEnabled == other.shiftRemindersEnabled &&
          shiftEndRemindersEnabled == other.shiftEndRemindersEnabled &&
          missedAttendanceRemindersEnabled == other.missedAttendanceRemindersEnabled &&
          leadTimeMinutes == other.leadTimeMinutes &&
          scheduleChangesEnabled == other.scheduleChangesEnabled &&
          securityAlertsEnabled == other.securityAlertsEnabled;

  @override
  int get hashCode => Object.hash(
        shiftRemindersEnabled,
        shiftEndRemindersEnabled,
        missedAttendanceRemindersEnabled,
        leadTimeMinutes,
        scheduleChangesEnabled,
        securityAlertsEnabled,
      );
}

final shiftNotificationPreferencesProvider =
    AsyncNotifierProvider<ShiftNotificationPreferencesNotifier, ShiftNotificationPreferences>(
  ShiftNotificationPreferencesNotifier.new,
);

class ShiftNotificationPreferencesNotifier extends AsyncNotifier<ShiftNotificationPreferences> {
  static const _prefix = 'pref_notif_';

  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  @override
  Future<ShiftNotificationPreferences> build() async {
    final storage = ref.watch(secureStorageServiceProvider);
    final startRemind = await storage.read('${_prefix}shift_start');
    final endRemind = await storage.read('${_prefix}shift_end');
    final missedRemind = await storage.read('${_prefix}missed_reminders');
    final leadMinutes = await storage.read('${_prefix}lead_minutes');
    final scheduleChanges = await storage.read('${_prefix}schedule_changes');
    final securityAlerts = await storage.read('${_prefix}security_alerts');

    return ShiftNotificationPreferences(
      shiftRemindersEnabled: startRemind != 'false',
      shiftEndRemindersEnabled: endRemind != 'false',
      missedAttendanceRemindersEnabled: missedRemind != 'false',
      leadTimeMinutes: int.tryParse(leadMinutes ?? '') ?? 15,
      scheduleChangesEnabled: scheduleChanges != 'false',
      securityAlertsEnabled: securityAlerts != 'false',
    );
  }

  Future<void> setShiftRemindersEnabled(bool value) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(shiftRemindersEnabled: value));
    await _storage.write('${_prefix}shift_start', value.toString());
    await ref.read(shiftReminderServiceProvider).syncShiftReminders();
  }

  Future<void> setShiftEndRemindersEnabled(bool value) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(shiftEndRemindersEnabled: value));
    await _storage.write('${_prefix}shift_end', value.toString());
    await ref.read(shiftReminderServiceProvider).syncShiftReminders();
  }

  Future<void> setMissedAttendanceRemindersEnabled(bool value) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(missedAttendanceRemindersEnabled: value));
    await _storage.write('${_prefix}missed_reminders', value.toString());
    await ref.read(shiftReminderServiceProvider).syncShiftReminders();
  }

  Future<void> setLeadTimeMinutes(int minutes) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(leadTimeMinutes: minutes));
    await _storage.write('${_prefix}lead_minutes', minutes.toString());
    await ref.read(shiftReminderServiceProvider).syncShiftReminders();
  }

  Future<void> setScheduleChangesEnabled(bool value) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(scheduleChangesEnabled: value));
    await _storage.write('${_prefix}schedule_changes', value.toString());
  }

  Future<void> setSecurityAlertsEnabled(bool value) async {
    final current = state.value ?? const ShiftNotificationPreferences();
    state = AsyncData(current.copyWith(securityAlertsEnabled: value));
    await _storage.write('${_prefix}security_alerts', value.toString());
  }
}

class ShiftReminderService {
  ShiftReminderService({
    required LocalNotificationService notificationService,
    EmployeeProfile? Function()? getProfile,
    ShiftNotificationPreferences Function()? getPreferences,
    bool Function()? getHasMarkedToday,
    void Function(String title, String body, NotificationCategory category)? onNotificationLogged,
  })  : _notificationService = notificationService,
        _getProfile = getProfile,
        _getPreferences = getPreferences,
        _getHasMarkedToday = getHasMarkedToday,
        _onNotificationLogged = onNotificationLogged;

  final LocalNotificationService _notificationService;
  final EmployeeProfile? Function()? _getProfile;
  final ShiftNotificationPreferences Function()? _getPreferences;
  final bool Function()? _getHasMarkedToday;
  final void Function(String title, String body, NotificationCategory category)? _onNotificationLogged;

  static const int shiftStartAlarmId = 1001;
  static const int shiftEndAlarmId = 1002;
  static const int shiftOverdueAlarmId = 1003;
  static const int shiftOverdueEndAlarmId = 1004;
  static const int testNotificationId = 999;

  /// Synchronizes scheduled alarms with the current assigned shift and user preferences.
  Future<void> syncShiftReminders({
    EmployeeShiftProfile? overrideShift,
    ShiftNotificationPreferences? overridePreferences,
  }) async {
    final profile = overrideShift != null ? null : _getProfile?.call();
    final shift = overrideShift ?? profile?.assignedShift;
    final preferences = overridePreferences ??
        _getPreferences?.call() ??
        const ShiftNotificationPreferences();
    final hasMarkedToday = _getHasMarkedToday?.call() ?? false;

    if (shift == null) {
      await _notificationService.cancelAlarm(shiftStartAlarmId);
      await _notificationService.cancelAlarm(shiftEndAlarmId);
      await _notificationService.cancelAlarm(shiftOverdueAlarmId);
      await _notificationService.cancelAlarm(shiftOverdueEndAlarmId);
      return;
    }

    final now = DateTime.now();
    final todayStart = getTodayTime(shift.startTime, now);
    final todayEnd = getTodayTime(shift.endTime, now);

    // 1. Shift Start & Overdue Reminders
    if (hasMarkedToday) {
      // Employee already marked attendance today:
      // Cancel early reminder and overdue reminder so they are not disturbed.
      await _notificationService.cancelAlarm(shiftStartAlarmId);
      await _notificationService.cancelAlarm(shiftOverdueAlarmId);
    } else {
      // Employee has NOT marked attendance yet:
      if (preferences.shiftRemindersEnabled) {
        final startTime = computeNextAlarmTime(
          timeStr: shift.startTime,
          now: now,
          offsetMinutes: preferences.leadTimeMinutes,
        );
        if (startTime != null) {
          final formattedShiftTime = formatTimeString(shift.startTime);
          await _notificationService.scheduleAlarm(
            id: shiftStartAlarmId,
            scheduledTime: startTime,
            title: 'Upcoming Shift: ${shift.name}',
            message:
                'Your shift starts at $formattedShiftTime (${preferences.leadTimeMinutes}m reminder). Don\'t forget to clock in!',
          );
        }
      } else {
        await _notificationService.cancelAlarm(shiftStartAlarmId);
      }

      // Check for Overdue Attendance Reminder
      if (preferences.missedAttendanceRemindersEnabled && todayStart != null) {
        final graceMinutes = shift.gracePeriodMinutes > 0 ? shift.gracePeriodMinutes : 15;
        final overdueTriggerTime = todayStart.add(Duration(minutes: graceMinutes));

        if (now.isAfter(overdueTriggerTime)) {
          // Time is ALREADY PASSED today and user hasn't marked attendance yet!
          final cutoffTime = todayEnd ?? DateTime(now.year, now.month, now.day, 23, 59);
          if (now.isBefore(cutoffTime)) {
            final formattedShiftTime = formatTimeString(shift.startTime);
            const overdueTitle = 'Attendance Overdue';
            final overdueMsg =
                'Your shift (${shift.name}) started at $formattedShiftTime. You haven\'t clocked in yet — please mark your attendance now.';

            await _notificationService.showNotification(
              id: shiftOverdueAlarmId,
              title: overdueTitle,
              message: overdueMsg,
            );
            _onNotificationLogged?.call(
              overdueTitle,
              overdueMsg,
              NotificationCategory.overdueAttendance,
            );
          }

          // Schedule tomorrow's overdue alarm
          final tomorrowOverdue = overdueTriggerTime.add(const Duration(days: 1));
          final formattedShiftTime = formatTimeString(shift.startTime);
          await _notificationService.scheduleAlarm(
            id: shiftOverdueAlarmId,
            scheduledTime: tomorrowOverdue,
            title: 'Attendance Overdue: ${shift.name}',
            message:
                'Your shift started at $formattedShiftTime. Please mark your attendance now to avoid being marked late or absent.',
          );
        } else {
          // Overdue time is still in the future TODAY: schedule it for today!
          final formattedShiftTime = formatTimeString(shift.startTime);
          await _notificationService.scheduleAlarm(
            id: shiftOverdueAlarmId,
            scheduledTime: overdueTriggerTime,
            title: 'Attendance Overdue: ${shift.name}',
            message:
                'Your shift started at $formattedShiftTime. Please mark your attendance now to avoid being marked late or absent.',
          );
        }
      } else {
        await _notificationService.cancelAlarm(shiftOverdueAlarmId);
      }
    }

    // 2. Shift End Reminder
    if (preferences.shiftEndRemindersEnabled) {
      final endTime = computeNextAlarmTime(
        timeStr: shift.endTime,
        now: now,
        offsetMinutes: 0,
      );
      if (endTime != null) {
        final formattedEndTime = formatTimeString(shift.endTime);
        await _notificationService.scheduleAlarm(
          id: shiftEndAlarmId,
          scheduledTime: endTime,
          title: 'Shift Ending: ${shift.name}',
          message:
              'Your shift ends at $formattedEndTime. Please remember to mark your check-out punch!',
        );
      }
    } else {
      await _notificationService.cancelAlarm(shiftEndAlarmId);
    }
  }

  /// Sends an immediate test notification to verify device alerts and notification shade display.
  Future<bool> sendTestNotification() async {
    final hasPerm = await _notificationService.hasPermission();
    if (!hasPerm) {
      final granted = await _notificationService.requestPermission();
      if (!granted) return false;
    }

    const testTitle = 'TKS Nexa Notification Active';
    const testMsg =
        'Shift reminders and attendance alerts are configured and working properly on this device.';

    final ok = await _notificationService.showNotification(
      id: testNotificationId,
      title: testTitle,
      message: testMsg,
    );

    if (ok) {
      _onNotificationLogged?.call(
        testTitle,
        testMsg,
        NotificationCategory.system,
      );
    }

    return ok;
  }

  Future<bool> openNotificationSettings() {
    return _notificationService.openSettings();
  }

  static DateTime? getTodayTime(String timeStr, DateTime now) {
    final tod = parseTimeString(timeStr);
    if (tod == null) return null;
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  static DateTime? computeNextAlarmTime({
    required String timeStr,
    required DateTime now,
    int offsetMinutes = 0,
  }) {
    final tod = parseTimeString(timeStr);
    if (tod == null) return null;

    var target = DateTime(
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    ).subtract(Duration(minutes: offsetMinutes));

    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  static TimeOfDay? parseTimeString(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    final isPm = clean.toUpperCase().contains('PM');
    final isAm = clean.toUpperCase().contains('AM');
    final digitsOnly = clean.replaceAll(RegExp(r'[^\d:]'), '');
    final parts = digitsOnly.split(':');
    if (parts.isEmpty) return null;

    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatTimeString(String raw) {
    final tod = parseTimeString(raw);
    if (tod == null) return raw;

    final period = tod.hour >= 12 ? 'PM' : 'AM';
    final standardHour = tod.hour % 12 == 0 ? 12 : tod.hour % 12;
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    return '$standardHour:$minuteStr $period';
  }
}

final shiftReminderServiceProvider = Provider<ShiftReminderService>(
  (ref) => ShiftReminderService(
    notificationService: ref.watch(localNotificationServiceProvider),
    getProfile: () => ref.read(employeeProfileProvider).value,
    getPreferences: () =>
        ref.read(shiftNotificationPreferencesProvider).value ??
        const ShiftNotificationPreferences(),
    getHasMarkedToday: () {
      final history = ref.read(attendanceHistoryResponseProvider).value;
      if (history == null) return false;
      final now = DateTime.now();
      final todayRec = history.records.where((r) =>
          r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day).firstOrNull;
      return todayRec != null &&
          todayRec.firstInFormatted != null &&
          todayRec.firstInFormatted != '--:--';
    },
    onNotificationLogged: (title, body, category) {
      ref.read(notificationInboxProvider.notifier).addNotification(
            title: title,
            body: body,
            category: category,
          );
    },
  ),
);

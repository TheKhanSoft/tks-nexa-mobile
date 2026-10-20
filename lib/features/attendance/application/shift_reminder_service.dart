import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/application/local_notification_service.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

class ShiftNotificationPreferences {
  const ShiftNotificationPreferences({
    this.shiftRemindersEnabled = true,
    this.shiftEndRemindersEnabled = true,
    this.leadTimeMinutes = 15,
    this.scheduleChangesEnabled = true,
    this.securityAlertsEnabled = true,
  });

  final bool shiftRemindersEnabled;
  final bool shiftEndRemindersEnabled;
  final int leadTimeMinutes;
  final bool scheduleChangesEnabled;
  final bool securityAlertsEnabled;

  ShiftNotificationPreferences copyWith({
    bool? shiftRemindersEnabled,
    bool? shiftEndRemindersEnabled,
    int? leadTimeMinutes,
    bool? scheduleChangesEnabled,
    bool? securityAlertsEnabled,
  }) {
    return ShiftNotificationPreferences(
      shiftRemindersEnabled: shiftRemindersEnabled ?? this.shiftRemindersEnabled,
      shiftEndRemindersEnabled: shiftEndRemindersEnabled ?? this.shiftEndRemindersEnabled,
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
          leadTimeMinutes == other.leadTimeMinutes &&
          scheduleChangesEnabled == other.scheduleChangesEnabled &&
          securityAlertsEnabled == other.securityAlertsEnabled;

  @override
  int get hashCode => Object.hash(
        shiftRemindersEnabled,
        shiftEndRemindersEnabled,
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
    final leadMinutes = await storage.read('${_prefix}lead_minutes');
    final scheduleChanges = await storage.read('${_prefix}schedule_changes');
    final securityAlerts = await storage.read('${_prefix}security_alerts');

    return ShiftNotificationPreferences(
      shiftRemindersEnabled: startRemind != 'false',
      shiftEndRemindersEnabled: endRemind != 'false',
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
  })  : _notificationService = notificationService,
        _getProfile = getProfile,
        _getPreferences = getPreferences;

  final LocalNotificationService _notificationService;
  final EmployeeProfile? Function()? _getProfile;
  final ShiftNotificationPreferences Function()? _getPreferences;

  static const int shiftStartAlarmId = 1001;
  static const int shiftEndAlarmId = 1002;
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

    if (shift == null) {
      await _notificationService.cancelAlarm(shiftStartAlarmId);
      await _notificationService.cancelAlarm(shiftEndAlarmId);
      return;
    }

    final now = DateTime.now();

    // 1. Shift Start Reminder
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

    return _notificationService.showNotification(
      id: testNotificationId,
      title: 'TKS Nexa Notification Active',
      message: 'Shift reminders and security alerts are configured and working properly on this device.',
    );
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
  ),
);

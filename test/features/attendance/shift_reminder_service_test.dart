import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/application/local_notification_service.dart';
import 'package:tks_nexa_attendance/features/attendance/application/shift_reminder_service.dart';

class MockLocalNotificationService implements LocalNotificationService {
  bool permissionGranted = true;
  final List<Map<String, dynamic>> scheduledAlarms = [];
  final List<int> canceledAlarms = [];
  final List<Map<String, dynamic>> immediateNotifications = [];
  bool allCanceled = false;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionGranted = true;
    return true;
  }

  @override
  Future<bool> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
  }) async {
    scheduledAlarms.add({
      'id': id,
      'scheduledTime': scheduledTime,
      'title': title,
      'message': message,
    });
    return true;
  }

  @override
  Future<bool> cancelAlarm(int id) async {
    canceledAlarms.add(id);
    return true;
  }

  @override
  Future<bool> cancelAllAlarms() async {
    allCanceled = true;
    return true;
  }

  @override
  Future<bool> showNotification({
    required int id,
    required String title,
    required String message,
  }) async {
    immediateNotifications.add({
      'id': id,
      'title': title,
      'message': message,
    });
    return true;
  }
}

void main() {
  group('ShiftReminderService Time Parsing & Computations', () {
    test('parseTimeString handles 24-hour and 12-hour strings', () {
      final t1 = ShiftReminderService.parseTimeString('08:00:00');
      expect(t1?.hour, equals(8));
      expect(t1?.minute, equals(0));

      final t2 = ShiftReminderService.parseTimeString('17:30:00');
      expect(t2?.hour, equals(17));
      expect(t2?.minute, equals(30));

      final t3 = ShiftReminderService.parseTimeString('08:15 AM');
      expect(t3?.hour, equals(8));
      expect(t3?.minute, equals(15));

      final t4 = ShiftReminderService.parseTimeString('05:45 PM');
      expect(t4?.hour, equals(17));
      expect(t4?.minute, equals(45));

      final t5 = ShiftReminderService.parseTimeString('12:00 PM');
      expect(t5?.hour, equals(12));
      expect(t5?.minute, equals(0));
    });

    test('formatTimeString produces user-friendly 12-hour display strings', () {
      expect(ShiftReminderService.formatTimeString('08:00:00'), equals('8:00 AM'));
      expect(ShiftReminderService.formatTimeString('17:00:00'), equals('5:00 PM'));
      expect(ShiftReminderService.formatTimeString('12:30:00'), equals('12:30 PM'));
      expect(ShiftReminderService.formatTimeString('00:15:00'), equals('12:15 AM'));
    });

    test('computeNextAlarmTime schedules for today if time is in future', () {
      final reference = DateTime(2026, 10, 20, 7, 0); // 7:00 AM
      final target = ShiftReminderService.computeNextAlarmTime(
        timeStr: '08:00:00',
        now: reference,
        offsetMinutes: 15, // 7:45 AM
      );

      expect(target, isNotNull);
      expect(target!.year, equals(2026));
      expect(target.month, equals(10));
      expect(target.day, equals(20));
      expect(target.hour, equals(7));
      expect(target.minute, equals(45));
    });

    test('computeNextAlarmTime advances to tomorrow if time has already passed today', () {
      final reference = DateTime(2026, 10, 20, 9, 0); // 9:00 AM (after 8:00 AM)
      final target = ShiftReminderService.computeNextAlarmTime(
        timeStr: '08:00:00',
        now: reference,
        offsetMinutes: 15, // 7:45 AM (passed)
      );

      expect(target, isNotNull);
      expect(target!.year, equals(2026));
      expect(target.month, equals(10));
      expect(target.day, equals(21)); // Tomorrow!
      expect(target.hour, equals(7));
      expect(target.minute, equals(45));
    });
  });

  group('ShiftNotificationPreferences Model Tests', () {
    test('has expected defaults and supports copyWith', () {
      const prefs = ShiftNotificationPreferences();
      expect(prefs.shiftRemindersEnabled, isTrue);
      expect(prefs.shiftEndRemindersEnabled, isTrue);
      expect(prefs.leadTimeMinutes, equals(15));
      expect(prefs.scheduleChangesEnabled, isTrue);
      expect(prefs.securityAlertsEnabled, isTrue);

      final updated = prefs.copyWith(
        shiftRemindersEnabled: false,
        leadTimeMinutes: 30,
      );
      expect(updated.shiftRemindersEnabled, isFalse);
      expect(updated.leadTimeMinutes, equals(30));
      expect(updated.shiftEndRemindersEnabled, isTrue);
    });
  });

  group('ShiftReminderService Scheduling Tests', () {
    late MockLocalNotificationService mockNotificationService;

    const testShift = EmployeeShiftProfile(
      name: 'Morning Shift',
      code: 'MS-1',
      startTime: '08:00:00',
      endTime: '16:00:00',
      gracePeriodMinutes: 15,
      isOvernight: false,
    );

    setUp(() {
      mockNotificationService = MockLocalNotificationService();
    });

    test('schedules both shift start and shift end alarms when enabled', () async {
      final service = ShiftReminderService(
        notificationService: mockNotificationService,
      );

      await service.syncShiftReminders(
        overrideShift: testShift,
        overridePreferences: const ShiftNotificationPreferences(
          shiftRemindersEnabled: true,
          shiftEndRemindersEnabled: true,
          leadTimeMinutes: 15,
        ),
      );

      expect(mockNotificationService.scheduledAlarms.length, equals(2));

      final startAlarm = mockNotificationService.scheduledAlarms.firstWhere(
        (a) => a['id'] == ShiftReminderService.shiftStartAlarmId,
      );
      expect(startAlarm['title'], contains('Upcoming Shift: Morning Shift'));
      expect(startAlarm['message'], contains('starts at 8:00 AM (15m reminder)'));

      final endAlarm = mockNotificationService.scheduledAlarms.firstWhere(
        (a) => a['id'] == ShiftReminderService.shiftEndAlarmId,
      );
      expect(endAlarm['title'], contains('Shift Ending: Morning Shift'));
      expect(endAlarm['message'], contains('ends at 4:00 PM'));
    });

    test('cancels shift start alarm when shiftRemindersEnabled is false', () async {
      final service = ShiftReminderService(
        notificationService: mockNotificationService,
      );

      await service.syncShiftReminders(
        overrideShift: testShift,
        overridePreferences: const ShiftNotificationPreferences(
          shiftRemindersEnabled: false,
          shiftEndRemindersEnabled: true,
        ),
      );

      expect(mockNotificationService.canceledAlarms, contains(ShiftReminderService.shiftStartAlarmId));
      expect(
        mockNotificationService.scheduledAlarms.any((a) => a['id'] == ShiftReminderService.shiftStartAlarmId),
        isFalse,
      );
      expect(
        mockNotificationService.scheduledAlarms.any((a) => a['id'] == ShiftReminderService.shiftEndAlarmId),
        isTrue,
      );
    });

    test('cancels both alarms when employee has no assigned shift', () async {
      final service = ShiftReminderService(
        notificationService: mockNotificationService,
      );

      await service.syncShiftReminders(
        overrideShift: null,
      );

      expect(mockNotificationService.canceledAlarms, contains(ShiftReminderService.shiftStartAlarmId));
      expect(mockNotificationService.canceledAlarms, contains(ShiftReminderService.shiftEndAlarmId));
      expect(mockNotificationService.scheduledAlarms.isEmpty, isTrue);
    });

    test('sendTestNotification triggers immediate notification with ID 999', () async {
      final service = ShiftReminderService(
        notificationService: mockNotificationService,
      );

      final result = await service.sendTestNotification();
      expect(result, isTrue);
      expect(mockNotificationService.immediateNotifications.length, equals(1));
      expect(mockNotificationService.immediateNotifications.first['id'], equals(ShiftReminderService.testNotificationId));
      expect(mockNotificationService.immediateNotifications.first['title'], equals('TKS Nexa Notification Active'));
    });
  });
}

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/notifications/application/notification_inbox_service.dart';
import 'package:tks_nexa_attendance/features/notifications/data/notification_inbox_storage.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';

class MemoryNotificationInboxStorage implements NotificationInboxStorage {
  List<AppNotificationItem> _items = [];

  @override
  Future<List<AppNotificationItem>> loadNotifications() async => List.unmodifiable(_items);

  @override
  Future<void> saveNotifications(List<AppNotificationItem> items) async {
    _items = List.of(items);
  }

  @override
  Future<void> clearAll() async {
    _items = [];
  }
}

void main() {
  group('AppNotificationItem Model', () {
    test('toJson and fromJson serialize properly', () {
      final now = DateTime(2026, 10, 21, 9, 30);
      final item = AppNotificationItem(
        id: 'notif_123',
        title: 'Overdue Alert',
        body: 'Shift started 15 min ago',
        category: NotificationCategory.overdueAttendance,
        createdAt: now,
        isRead: false,
        route: '/attendance/prepare',
      );

      final json = item.toJson();
      expect(json['id'], equals('notif_123'));
      expect(json['category'], equals('overdueAttendance'));
      expect(json['is_read'], isFalse);

      final parsed = AppNotificationItem.fromJson(json);
      expect(parsed.id, equals(item.id));
      expect(parsed.title, equals(item.title));
      expect(parsed.body, equals(item.body));
      expect(parsed.category, equals(NotificationCategory.overdueAttendance));
      expect(parsed.isRead, isFalse);
      expect(parsed.route, equals('/attendance/prepare'));
    });

    test('copyWith updates fields correctly', () {
      final item = AppNotificationItem(
        id: 'notif_1',
        title: 'Title',
        body: 'Body',
        category: NotificationCategory.shiftReminder,
        createdAt: DateTime.now(),
        isRead: false,
      );

      final readItem = item.copyWith(isRead: true);
      expect(readItem.isRead, isTrue);
      expect(readItem.title, equals('Title'));
    });
  });

  group('NotificationInboxStorage File I/O', () {
    late Directory tempDir;
    late NotificationInboxStorage storage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('notif_test_');
      storage = FileNotificationInboxStorage(baseDirectory: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('saves and loads notification items to disk', () async {
      final item1 = AppNotificationItem(
        id: '1',
        title: 'Notice 1',
        body: 'Body 1',
        category: NotificationCategory.system,
        createdAt: DateTime.now(),
      );

      await storage.saveNotifications([item1]);
      final loaded = await storage.loadNotifications();

      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('1'));
      expect(loaded.first.title, equals('Notice 1'));
    });

    test('clearAll wipes notifications file', () async {
      final item1 = AppNotificationItem(
        id: '1',
        title: 'Notice 1',
        body: 'Body 1',
        category: NotificationCategory.system,
        createdAt: DateTime.now(),
      );

      await storage.saveNotifications([item1]);
      await storage.clearAll();
      final loaded = await storage.loadNotifications();

      expect(loaded.isEmpty, isTrue);
    });
  });

  group('NotificationInboxController Riverpod Notifier', () {
    late ProviderContainer container;
    late MemoryNotificationInboxStorage memoryStorage;

    setUp(() {
      memoryStorage = MemoryNotificationInboxStorage();
      container = ProviderContainer(
        overrides: [
          notificationInboxStorageProvider.overrideWithValue(memoryStorage),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('addNotification adds item to head and updates unread count', () async {
      final controller = container.read(notificationInboxProvider.notifier);

      await controller.addNotification(
        title: 'Shift Reminder',
        body: 'Your shift starts in 15 minutes',
        category: NotificationCategory.shiftReminder,
      );

      final items = container.read(notificationInboxProvider).value ?? [];
      expect(items.length, equals(1));
      expect(items.first.title, equals('Shift Reminder'));
      expect(items.first.isRead, isFalse);

      final unreadCount = container.read(unreadNotificationsCountProvider);
      expect(unreadCount, equals(1));
    });

    test('markAsRead and markAsUnread toggle notification status', () async {
      final controller = container.read(notificationInboxProvider.notifier);

      await controller.addNotification(
        title: 'Overdue',
        body: 'Clock in now',
        category: NotificationCategory.overdueAttendance,
      );

      final id = container.read(notificationInboxProvider).value!.first.id;

      await controller.markAsRead(id);
      expect(container.read(notificationInboxProvider).value!.first.isRead, isTrue);
      expect(container.read(unreadNotificationsCountProvider), equals(0));

      await controller.markAsUnread(id);
      expect(container.read(notificationInboxProvider).value!.first.isRead, isFalse);
      expect(container.read(unreadNotificationsCountProvider), equals(1));
    });

    test('markAllAsRead marks all items read', () async {
      final controller = container.read(notificationInboxProvider.notifier);

      await controller.addNotification(title: 'Notice 1', body: 'Body 1');
      await controller.addNotification(title: 'Notice 2', body: 'Body 2');

      expect(container.read(unreadNotificationsCountProvider), equals(2));

      await controller.markAllAsRead();
      final items = container.read(notificationInboxProvider).value!;
      expect(items.every((i) => i.isRead), isTrue);
      expect(container.read(unreadNotificationsCountProvider), equals(0));
    });

    test('deleteNotification and deleteSelected remove targeted notifications', () async {
      final controller = container.read(notificationInboxProvider.notifier);

      await controller.addNotification(title: 'N1', body: 'B1');
      await controller.addNotification(title: 'N2', body: 'B2');
      await controller.addNotification(title: 'N3', body: 'B3');

      final items = container.read(notificationInboxProvider).value!;
      final idToDelete = items.first.id;

      await controller.deleteNotification(idToDelete);
      expect(container.read(notificationInboxProvider).value!.length, equals(2));
      expect(container.read(notificationInboxProvider).value!.any((i) => i.id == idToDelete), isFalse);

      final remainingIds = container.read(notificationInboxProvider).value!.map((i) => i.id).toSet();
      await controller.deleteSelected(remainingIds);
      expect(container.read(notificationInboxProvider).value!.isEmpty, isTrue);
    });

    test('clearAll removes all notifications', () async {
      final controller = container.read(notificationInboxProvider.notifier);

      await controller.addNotification(title: 'N1', body: 'B1');
      await controller.addNotification(title: 'N2', body: 'B2');

      await controller.clearAll();
      expect(container.read(notificationInboxProvider).value!.isEmpty, isTrue);
      expect(container.read(unreadNotificationsCountProvider), equals(0));
    });
  });
}

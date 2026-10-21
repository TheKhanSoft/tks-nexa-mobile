import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/notifications/data/notification_inbox_storage.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';

final notificationInboxProvider =
    AsyncNotifierProvider<NotificationInboxController, List<AppNotificationItem>>(
  NotificationInboxController.new,
);

class NotificationInboxController extends AsyncNotifier<List<AppNotificationItem>> {
  NotificationInboxStorage get _storage => ref.read(notificationInboxStorageProvider);

  @override
  FutureOr<List<AppNotificationItem>> build() async {
    final storage = ref.watch(notificationInboxStorageProvider);
    final items = await storage.loadNotifications();
    return items;
  }

  Future<List<AppNotificationItem>> _getCurrentItems() async {
    if (state.hasValue) return state.value!;
    try {
      return await future;
    } catch (_) {
      return [];
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
    String? route,
    Map<String, dynamic> payload = const {},
  }) async {
    final current = await _getCurrentItems();
    final id = 'notif_${DateTime.now().millisecondsSinceEpoch}_${current.length + 1}';
    final newItem = AppNotificationItem(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
      isRead: false,
      route: route,
      payload: payload,
    );

    final updated = [newItem, ...current];
    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> markAsRead(String id) async {
    final current = await _getCurrentItems();
    final updated = current.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList(growable: false);

    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> markAsUnread(String id) async {
    final current = await _getCurrentItems();
    final updated = current.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: false);
      }
      return item;
    }).toList(growable: false);

    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> markAllAsRead() async {
    final current = await _getCurrentItems();
    final updated = current.map((item) => item.copyWith(isRead: true)).toList(growable: false);

    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> deleteNotification(String id) async {
    final current = await _getCurrentItems();
    final updated = current.where((item) => item.id != id).toList(growable: false);

    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> deleteSelected(Set<String> ids) async {
    final current = await _getCurrentItems();
    final updated = current.where((item) => !ids.contains(item.id)).toList(growable: false);

    state = AsyncData(updated);
    await _storage.saveNotifications(updated);
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    await _storage.clearAll();
  }
}

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationInboxProvider).value;
  if (items == null) return 0;
  return items.where((i) => !i.isRead).length;
});

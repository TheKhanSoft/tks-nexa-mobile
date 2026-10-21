import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';

abstract interface class NotificationInboxStorage {
  Future<List<AppNotificationItem>> loadNotifications();
  Future<void> saveNotifications(List<AppNotificationItem> items);
  Future<void> clearAll();
}

class FileNotificationInboxStorage implements NotificationInboxStorage {
  FileNotificationInboxStorage({Directory? baseDirectory})
      : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<File> _getFile() async {
    final Directory dir;
    if (_baseDirectory != null) {
      dir = _baseDirectory!;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dir = Directory('${docDir.path}/notification_inbox');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/notifications.json');
  }

  @override
  Future<List<AppNotificationItem>> loadNotifications() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((m) => AppNotificationItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveNotifications(List<AppNotificationItem> items) async {
    try {
      final file = await _getFile();
      final data = jsonEncode(items.map((i) => i.toJson()).toList(growable: false));
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(data, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

final notificationInboxStorageProvider = Provider<NotificationInboxStorage>((ref) {
  return FileNotificationInboxStorage();
});

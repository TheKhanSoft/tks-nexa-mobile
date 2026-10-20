import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class LocalNotificationService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<bool> showNotification({
    required int id,
    required String title,
    required String message,
  });
  Future<bool> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
  });
  Future<bool> cancelAlarm(int id);
  Future<bool> cancelAllAlarms();
}

class PlatformLocalNotificationService implements LocalNotificationService {
  PlatformLocalNotificationService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.tksnexa.thekhansoft/notifications');

  final MethodChannel _channel;

  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasNotificationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> showNotification({
    required int id,
    required String title,
    required String message,
  }) async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'title': title,
        'message': message,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String message,
  }) async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'id': id,
        'triggerAtMillis': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'message': message,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> cancelAlarm(int id) async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('cancelAlarm', {'id': id});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> cancelAllAlarms() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('cancelAllAlarms');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => PlatformLocalNotificationService(),
);

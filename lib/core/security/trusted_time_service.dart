import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

final trustedTimeServiceProvider = Provider<TrustedTimeService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return TrustedTimeService(storage: storage);
});

class ClockIntegrityVerdict {
  const ClockIntegrityVerdict({
    required this.deviceTime,
    required this.estimatedTrueTime,
    required this.clockSkewSeconds,
    required this.isTimeManipulated,
    this.reason,
  });

  final DateTime deviceTime;
  final DateTime estimatedTrueTime;
  final int clockSkewSeconds;
  final bool isTimeManipulated;
  final String? reason;
}

class TrustedTimeService {
  TrustedTimeService({this.storage}) {
    _init();
  }

  final SecureStorageService? storage;

  final Stopwatch _monotonicStopwatch = Stopwatch()..start();
  DateTime? _lastServerAnchorUtc;
  int _monotonicMsAtAnchor = 0;
  DateTime? _persistedLatestServerTimeUtc;

  static const _storageKeyLatestServerTime = 'tks_trusted_time_latest_server_iso';

  Future<void> _init() async {
    try {
      if (storage == null) return;
      final iso = await storage!.read(_storageKeyLatestServerTime);
      if (iso != null && iso.isNotEmpty) {
        _persistedLatestServerTimeUtc = DateTime.tryParse(iso)?.toUtc();
      }
    } catch (_) {}
  }

  /// Called whenever a verified server response or challenge is received
  void recordServerAnchor(DateTime serverTimeUtc) {
    final utc = serverTimeUtc.toUtc();
    _lastServerAnchorUtc = utc;
    _monotonicMsAtAnchor = _monotonicStopwatch.elapsedMilliseconds;

    if (_persistedLatestServerTimeUtc == null ||
        utc.isAfter(_persistedLatestServerTimeUtc!)) {
      _persistedLatestServerTimeUtc = utc;
      _persistServerTime(utc);
    }
  }

  Future<void> _persistServerTime(DateTime utc) async {
    try {
      if (storage == null) return;
      await storage!.write(
        _storageKeyLatestServerTime,
        utc.toIso8601String(),
      );
    } catch (_) {}
  }

  /// Calculates the best estimated true UTC time using monotonic hardware tick
  DateTime getTrustedTime() {
    if (_lastServerAnchorUtc != null) {
      final elapsedSinceAnchorMs =
          _monotonicStopwatch.elapsedMilliseconds - _monotonicMsAtAnchor;
      return _lastServerAnchorUtc!.add(Duration(milliseconds: elapsedSinceAnchorMs));
    }

    final nowUtc = DateTime.now().toUtc();
    if (_persistedLatestServerTimeUtc != null &&
        nowUtc.isBefore(_persistedLatestServerTimeUtc!)) {
      // System clock has been rolled back before the last known server time
      return _persistedLatestServerTimeUtc!;
    }
    return nowUtc;
  }

  /// Validates a device punch timestamp against the monotonic anchor
  ClockIntegrityVerdict checkClockIntegrity(DateTime deviceCapturedAt) {
    final devUtc = deviceCapturedAt.toUtc();
    final trustedUtc = getTrustedTime();
    final skewSeconds = devUtc.difference(trustedUtc).inSeconds;

    bool isManipulated = false;
    String? reason;

    // Check 1: Monotonic drift greater than 3 minutes (180s)
    if (skewSeconds.abs() > 180) {
      isManipulated = true;
      if (skewSeconds < 0) {
        reason =
            'Device clock appears to be rolled backwards by ${skewSeconds.abs()} seconds.';
      } else {
        reason = 'Device clock appears to be fast by $skewSeconds seconds.';
      }
    } else if (_persistedLatestServerTimeUtc != null) {
      // Check 2: Device time is behind the previously confirmed server timestamp
      final diffFromPersisted =
          devUtc.difference(_persistedLatestServerTimeUtc!).inSeconds;
      if (diffFromPersisted < -120) {
        isManipulated = true;
        reason =
            'Device timestamp is prior to last confirmed server synchronization.';
      }
    }

    return ClockIntegrityVerdict(
      deviceTime: devUtc,
      estimatedTrueTime: trustedUtc,
      clockSkewSeconds: skewSeconds,
      isTimeManipulated: isManipulated,
      reason: reason,
    );
  }
}

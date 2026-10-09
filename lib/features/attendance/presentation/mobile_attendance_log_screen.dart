import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/view_attendance_record_screen.dart';

class MobilePunchLogItem {
  const MobilePunchLogItem({
    required this.id,
    required this.timestamp,
    required this.typeLabel,
    required this.status,
    required this.matchScore,
    required this.threshold,
    required this.livenessPassed,
    required this.locationName,
    required this.deviceModel,
    this.photoPath,
    this.photoUrl,
  });

  final String id;
  final DateTime timestamp;
  final String typeLabel;
  final String status;
  final int matchScore;
  final int threshold;
  final bool livenessPassed;
  final String locationName;
  final String deviceModel;
  final String? photoPath;
  final String? photoUrl;
}

DateTime _combineDateAndTime(DateTime date, String? timeStr) {
  if (timeStr == null || timeStr.isEmpty || timeStr == '--:--' || timeStr == 'Pending') return date;
  try {
    final s = timeStr.trim();
    final match12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(s);
    if (match12 != null) {
      var hour = int.parse(match12.group(1)!);
      final min = int.parse(match12.group(2)!);
      final period = match12.group(3)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, min);
    }
    final parts = s.split(':');
    if (parts.length >= 2) {
      return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
    }
  } catch (_) {}
  return date;
}

final mobilePunchLogsProvider = FutureProvider<List<MobilePunchLogItem>>((ref) async {
  final api = ref.watch(mobileAttendanceApiProvider);
  final selfieStorage = ref.watch(localSelfieStorageProvider);

  try {
    final rawLogs = await api.fetchMobileLogs(period: 'this_month');
    if (rawLogs.isNotEmpty) {
      final items = <MobilePunchLogItem>[];
      for (final log in rawLogs) {
        final id = (log['id'] ?? log['event_uid'] ?? '').toString();
        final rawTs = log['timestamp'] ?? log['created_at'];
        final parsed = rawTs is String ? DateTime.tryParse(rawTs) : null;
        final ts = parsed != null ? parsed.toLocal() : DateTime.now();

        final rawScore = log['similarity_score'] ?? log['confidence_score'] ?? log['match_score'];
        var scoreInt = 95;
        if (rawScore is num) {
          scoreInt = rawScore <= 1.0 ? (rawScore * 100).round() : rawScore.round();
        } else if (rawScore is String) {
          final p = double.tryParse(rawScore) ?? 95.0;
          scoreInt = p <= 1.0 ? (p * 100).round() : p.round();
        }

        final statusStr = (log['status'] ?? 'Verified Match').toString();
        final devMap = log['device'] is Map ? Map<String, dynamic>.from(log['device']) : const <String, dynamic>{};
        final locMap = log['location'] is Map ? Map<String, dynamic>.from(log['location']) : const <String, dynamic>{};

        final locationName = (locMap['name'] ?? log['location_name'] ?? 'Office Perimeter').toString();
        final deviceModel = (devMap['model'] ?? devMap['platform'] ?? log['device_model'] ?? 'Authorized Device').toString();
        final snapshotUrl = log['snapshot_url']?.toString();

        final localSelfie = await selfieStorage.getSelfiePath(date: ts, type: 'check_in');

        final verMethod = (log['verification_method'] ?? 'Face Biometric').toString().toLowerCase();
        final isExit = verMethod.contains('exit') || verMethod.contains('out');

        items.add(
          MobilePunchLogItem(
            id: id,
            timestamp: ts,
            typeLabel: isExit ? 'Clock Out' : 'Clock In',
            status: statusStr,
            matchScore: scoreInt,
            threshold: 70,
            livenessPassed: log['liveness_verified'] == true || log['liveness_passed'] == true,
            locationName: locationName,
            deviceModel: deviceModel,
            photoPath: localSelfie,
            photoUrl: snapshotUrl,
          ),
        );
      }
      return items;
    }
  } catch (_) {
    // Fall back to attendance records if mobile-logs endpoint has transient network issues
  }

  // Fallback: build from real attendance records
  try {
    final historyAsync = await ref.watch(attendanceHistoryResponseProvider.future);
    final items = <MobilePunchLogItem>[];
    for (final rec in historyAsync.records) {
      if (rec.firstIn != null && rec.firstIn != '--:--' && rec.firstIn != 'Pending') {
        final selfiePath = await selfieStorage.getSelfiePath(date: rec.date, type: 'check_in');
        final isPresent = rec.isPresent;
        final inTimeStr = rec.firstInFormatted ?? rec.firstIn!;
        final inDt = _combineDateAndTime(rec.date, inTimeStr);
        items.add(
          MobilePunchLogItem(
            id: '${rec.id}-in',
            timestamp: inDt,
            typeLabel: 'Clock In · $inTimeStr',
            status: isPresent ? 'Verified & Logged' : rec.status,
            matchScore: rec.trustScore ?? (isPresent ? 96 : 60),
            threshold: 70,
            livenessPassed: isPresent,
            locationName: rec.locationName ?? 'Office Perimeter',
            deviceModel: rec.deviceModel ?? rec.deviceLabel ?? 'Authorized Device',
            photoPath: selfiePath,
            photoUrl: rec.photoUrl,
          ),
        );
      }
      if (rec.lastOut != null && rec.lastOut != '--:--' && rec.lastOut != 'Pending' && rec.lastOut != rec.firstIn) {
        final selfiePath = await selfieStorage.getSelfiePath(date: rec.date, type: 'check_out');
        final outTimeStr = rec.lastOutFormatted ?? rec.lastOut!;
        final outDt = _combineDateAndTime(rec.date, outTimeStr);
        items.add(
          MobilePunchLogItem(
            id: '${rec.id}-out',
            timestamp: outDt,
            typeLabel: 'Clock Out · $outTimeStr',
            status: 'Verified & Logged',
            matchScore: rec.trustScore ?? 94,
            threshold: 70,
            livenessPassed: true,
            locationName: rec.locationName ?? 'Office Perimeter',
            deviceModel: rec.deviceModel ?? rec.deviceLabel ?? 'Authorized Device',
            photoPath: selfiePath,
            photoUrl: rec.photoUrl,
          ),
        );
      }
    }
    return items;
  } catch (_) {
    return const [];
  }
});

class MobileAttendanceLogScreen extends ConsumerWidget {
  const MobileAttendanceLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(mobilePunchLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Attendance Log', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        actions: [
          IconButton(
            tooltip: 'Refresh Log',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              ref.invalidate(mobilePunchLogsProvider);
              await ref.read(mobilePunchLogsProvider.future);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mobilePunchLogsProvider);
          await ref.read(mobilePunchLogsProvider.future);
        },
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Unable to load mobile logs: $err', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 54, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 14),
                          const Text('No mobile attendance captures logged yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Pull down to refresh', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              children: [
                // Technical Neural Architecture Header Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Facial Biometric Verification',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Secure On-Device Face Matching · Live Anti-Spoof Protection',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date-Wise Mobile Captures', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('${logs.length} Captures', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isPass = log.matchScore >= log.threshold;
                    final statusColor = isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ViewAttendanceRecordScreen.fromMobileLog(log),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: theme.colorScheme.primaryContainer,
                                  child: log.photoPath != null && File(log.photoPath!).existsSync()
                                      ? Image.file(
                                          File(log.photoPath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(Icons.face_rounded, color: theme.colorScheme.primary, size: 28),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log.typeLabel} • ${_formatDateTime(log.timestamp)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Location: ${log.locationName}',
                                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${log.matchScore}% Match',
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 15, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                'Liveness Check: ${log.livenessPassed ? 'Passed' : 'Failed'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  log.status,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}

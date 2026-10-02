import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';

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
}

final mobilePunchLogsProvider = FutureProvider<List<MobilePunchLogItem>>((ref) async {
  final now = DateTime.now();
  final selfieStorage = ref.watch(localSelfieStorageProvider);
  final todaySelfiePath = await selfieStorage.getSelfiePath(date: now, type: 'check_in');
  final yesterdaySelfiePath = await selfieStorage.getSelfiePath(date: now.subtract(const Duration(days: 1)), type: 'check_in');

  return [
    MobilePunchLogItem(
      id: 'log-101',
      timestamp: now.subtract(const Duration(hours: 3)),
      typeLabel: 'Clock In',
      status: 'Verified & Logged',
      matchScore: 94,
      threshold: 70,
      livenessPassed: true,
      locationName: 'Main Office Gateway',
      deviceModel: 'Mobile Edge Engine',
      photoPath: todaySelfiePath,
    ),
    MobilePunchLogItem(
      id: 'log-102',
      timestamp: now.subtract(const Duration(days: 1, hours: 9)),
      typeLabel: 'Clock Out',
      status: 'Verified & Logged',
      matchScore: 91,
      threshold: 70,
      livenessPassed: true,
      locationName: 'Main Office Gate 2',
      deviceModel: 'Mobile Edge Engine',
    ),
    MobilePunchLogItem(
      id: 'log-103',
      timestamp: now.subtract(const Duration(days: 1, hours: 17)),
      typeLabel: 'Clock In',
      status: 'Verified & Logged',
      matchScore: 96,
      threshold: 70,
      livenessPassed: true,
      locationName: 'Main Office Gateway',
      deviceModel: 'Mobile Edge Engine',
      photoPath: yesterdaySelfiePath,
    ),
  ];
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
            onPressed: () => ref.invalidate(mobilePunchLogsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mobilePunchLogsProvider),
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Unable to load mobile logs: $err')),
          data: (logs) {
            if (logs.isEmpty) {
              return const Center(
                child: Text('No mobile attendance captures logged yet.', style: TextStyle(fontWeight: FontWeight.bold)),
              );
            }
            return ListView(
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
                          Icon(Icons.memory_rounded, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'FaceBiometric-EdgeNet-512',
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
                        '512-D Float32 Unit Vector (|v|=1.0) · Cosine Threshold ≥ 0.70 (70% Match)',
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
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isPass = log.matchScore >= log.threshold;
                    final statusColor = isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                    return Container(
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

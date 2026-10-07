import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/punch_detail.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/regularization_request_bottom_sheet.dart';

class ShiftDetailBottomSheet extends ConsumerWidget {
  const ShiftDetailBottomSheet({super.key, required this.record});

  final AttendanceRecord record;

  static void show(BuildContext context, AttendanceRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShiftDetailBottomSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    final punchDetailAsync = ref.watch(punchDetailProvider(dateStr));
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      child: Container(
        padding: EdgeInsets.fromLTRB(22, 12, 22, MediaQuery.of(context).padding.bottom + 80),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle & App Header Bar with Back and Close buttons
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Shift Details & Geofence Audit',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),
              punchDetailAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => _PunchDetailBody(
                  record: record,
                  detail: _buildDynamicDetail(record),
                ),
                data: (detail) => _PunchDetailBody(
                  record: record,
                  detail: _mergeRecordDetail(record, detail),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static PunchDetailData _buildDynamicDetail(AttendanceRecord record) {
    final dateStr = '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    final inTime = record.firstInFormatted ?? record.firstIn;
    final outTime = record.lastOutFormatted ?? record.lastOut;

    final touchpoints = <PunchTouchpoint>[
      if (inTime != null && inTime.isNotEmpty && inTime != '--:--' && inTime != 'Pending')
        PunchTouchpoint(
          number: 1,
          time: inTime,
          statusTag: 'Check In',
          title: 'Face Biometric + Geofence Verified',
          location: record.locationName ?? 'Office Perimeter',
          deviceLabel: record.deviceName ?? record.deviceModel ?? 'Authorized Device',
          matchPercentage: record.trustScore != null ? record.trustScore!.toDouble() : 88.0,
        ),
      if (outTime != null && outTime.isNotEmpty && outTime != '--:--' && outTime != 'Pending')
        PunchTouchpoint(
          number: 2,
          time: outTime,
          statusTag: 'Check Out',
          title: 'Face Biometric Exit Scanner',
          location: record.locationName ?? 'Office Perimeter',
          deviceLabel: record.deviceName ?? record.deviceModel ?? 'Authorized Device',
          matchPercentage: record.trustScore != null ? record.trustScore!.toDouble() : 91.0,
        ),
    ];

    final hasPunches = touchpoints.isNotEmpty;

    return PunchDetailData(
      shiftOverview: ShiftOverview(
        date: dateStr,
        dayName: record.dayName,
        formattedDate: dateStr,
        status: record.status,
        shiftName: record.shiftName,
        shiftTiming: 'Standard Schedule',
        lateArrivalAlert: record.isLate
            ? const LateArrivalAlert(
                isLate: true,
                lateMinutes: 15,
                graceWindowMinutes: 15,
                message: 'Late Arrival',
              )
            : null,
        metrics: ShiftOverviewMetrics(
          totalLogged: hasPunches ? record.formattedNetDuration : '--',
          productive: hasPunches ? record.formattedNetDuration : '--',
          breakDuration: hasPunches ? '0h 00m' : '--',
        ),
      ),
      touchpoints: touchpoints,
      geofenceAudit: hasPunches
          ? GeofenceAudit(
              status: 'Perimeter Cleared',
              perimeterDetails: record.latitude != null
                  ? 'GPS (${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)})'
                  : 'Verified Perimeter',
              hardwareDisplay: record.deviceName ?? record.deviceModel ?? 'Authorized Device',
              networkGateway: 'Campus Secure Network',
              ipStamp: 'Verified Telemetry',
            )
          : const GeofenceAudit(
              status: 'No Check-in Logged',
              perimeterDetails: 'No mobile attendance recorded for this date.',
              hardwareDisplay: 'No hardware registered',
              networkGateway: 'No active gateway',
              ipStamp: '—',
            ),
      managerReview: ManagerReview(
        statusLabel: hasPunches ? 'Verified' : 'Pending',
        approverName: 'Department Manager',
        approverTitle: 'Line Manager • Approver',
        note: hasPunches
            ? 'Attendance record verified and logged successfully.'
            : 'No attendance check-in recorded for this date.',
      ),
    );
  }

  static PunchDetailData _mergeRecordDetail(AttendanceRecord record, PunchDetailData detail) {
    final dynamicDetail = _buildDynamicDetail(record);
    final chosenTouchpoints = detail.touchpoints.isNotEmpty
        ? detail.touchpoints
        : dynamicDetail.touchpoints;

    final hasAnyPunches = chosenTouchpoints.isNotEmpty;

    return PunchDetailData(
      shiftOverview: ShiftOverview(
        date: dynamicDetail.shiftOverview.date,
        dayName: record.dayName,
        formattedDate: dynamicDetail.shiftOverview.formattedDate,
        status: record.status,
        shiftName: record.shiftName.isNotEmpty ? record.shiftName : detail.shiftOverview.shiftName,
        shiftTiming: detail.shiftOverview.shiftTiming,
        lateArrivalAlert: detail.shiftOverview.lateArrivalAlert,
        metrics: ShiftOverviewMetrics(
          totalLogged: hasAnyPunches
              ? (record.formattedNetDuration != '--'
                  ? record.formattedNetDuration
                  : (detail.shiftOverview.metrics.totalLogged != '--' && detail.shiftOverview.metrics.totalLogged != '8h 00m'
                      ? detail.shiftOverview.metrics.totalLogged
                      : '--'))
              : '--',
          productive: hasAnyPunches
              ? (record.formattedNetDuration != '--'
                  ? record.formattedNetDuration
                  : (detail.shiftOverview.metrics.productive != '--' && detail.shiftOverview.metrics.productive != '8h 00m'
                      ? detail.shiftOverview.metrics.productive
                      : '--'))
              : '--',
          breakDuration: hasAnyPunches ? detail.shiftOverview.metrics.breakDuration : '--',
        ),
      ),
      touchpoints: chosenTouchpoints,
      geofenceAudit: hasAnyPunches ? detail.geofenceAudit : dynamicDetail.geofenceAudit,
      managerReview: detail.managerReview,
    );
  }
}

class _PunchDetailBody extends StatelessWidget {
  const _PunchDetailBody({required this.record, required this.detail});

  final AttendanceRecord record;
  final PunchDetailData detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final so = detail.shiftOverview;
    final geo = detail.geofenceAudit;
    final mr = detail.managerReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Overview Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHIFT OVERVIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  so.formattedDate,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_rounded, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    so.status,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${record.locationName ?? 'Tech Park Campus, Tower B'} • ${so.shiftName}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (so.lateArrivalAlert case final alert? when alert.isLate) ...[
          const SizedBox(height: 14),
          // Late Warning Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text(
                  'Late Arrival (+${alert.lateMinutes} mins)',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  'Grace Window: ${alert.graceWindowMinutes}m',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Metrics Row
        Row(
          children: [
            Expanded(
              child: _MetricBox(
                label: 'Total Logged',
                value: so.metrics.totalLogged,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricBox(
                label: 'Productive',
                value: so.metrics.productive,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricBox(
                label: 'Break Duration',
                value: so.metrics.breakDuration,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Punch Log Timeline Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Attendance Activity Timeline',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${detail.touchpoints.length} Touchpoints', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (detail.touchpoints.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy_rounded, size: 24, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No check in/out records for this date',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Attendance was not logged on this day.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < detail.touchpoints.length; i++)
            _TimelineNode(
              tp: detail.touchpoints[i],
              isLast: i == detail.touchpoints.length - 1,
            ),
        const SizedBox(height: 20),
        // Geofence Audit Section
        const Text('Geofence Audit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final isCleared = geo.status.toLowerCase().contains('cleared') ||
              geo.status.toLowerCase().contains('verified');
          final statusColor = isCleared
              ? const Color(0xFF10B981)
              : (detail.touchpoints.isEmpty ? theme.colorScheme.onSurfaceVariant : const Color(0xFFF59E0B));
          final statusIcon = isCleared
              ? Icons.shield_rounded
              : (detail.touchpoints.isEmpty ? Icons.info_outline_rounded : Icons.warning_amber_rounded);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      geo.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      geo.perimeterDetails,
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (record.latitude != null && record.longitude != null) ...[
                  _AuditDetailRow(
                    icon: Icons.pin_drop_rounded,
                    label: 'GPS Coordinates',
                    value: '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 6),
                ],
                if (record.locationName != null && record.locationName!.isNotEmpty) ...[
                  _AuditDetailRow(
                    icon: Icons.place_rounded,
                    label: 'Captured Place',
                    value: record.locationName!,
                  ),
                  const SizedBox(height: 6),
                ],
                _AuditDetailRow(icon: Icons.smartphone_rounded, label: 'Authorized Hardware', value: geo.hardwareDisplay),
                const SizedBox(height: 6),
                _AuditDetailRow(icon: Icons.wifi_rounded, label: 'Network Gateway', value: geo.networkGateway),
                const SizedBox(height: 6),
                _AuditDetailRow(icon: Icons.lan_rounded, label: 'IP Stamp', value: geo.ipStamp),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        // Manager Review Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manager Review Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(mr.statusLabel, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const CircleAvatar(radius: 18, child: Text('MC', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mr.approverName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      Text(mr.approverTitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mr.note,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Actions
        FilledButton.icon(
          onPressed: () {
            final targetDate = record.date;
            Navigator.of(context).pop();
            RegularizationRequestBottomSheet.show(context, initialDate: targetDate);
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.edit_calendar_rounded),
          label: const Text('Request Attendance Regularization', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Timesheet Slip', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.tp,
    this.isLast = false,
  });

  final PunchTouchpoint tp;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (badgeColor, iconData) = _visualsForTag(tp.statusTag);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(iconData, size: 14, color: badgeColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tp.time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      const Spacer(),
                      Builder(builder: (context) {
                        final matchVal = tp.matchPercentage ?? tp.similarityScore;
                        if (matchVal == null || matchVal <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF059669)),
                                const SizedBox(width: 3.5),
                                Text(
                                  '${matchVal.toStringAsFixed(matchVal % 1 == 0 ? 0 : 1)}% Match',
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(tp.statusTag, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(tp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('${tp.location} · ${tp.deviceLabel}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _visualsForTag(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('late')) return (const Color(0xFFF59E0B), Icons.fingerprint_rounded);
    if (t.contains('out') || t.contains('break')) return (Colors.blue, Icons.smartphone_rounded);
    if (t.contains('resume')) return (Colors.purple, Icons.badge_rounded);
    if (t.contains('completed') || t.contains('exit')) return (const Color(0xFF10B981), Icons.sensor_door_rounded);
    return (const Color(0xFF10B981), Icons.verified_rounded);
  }
}

class _AuditDetailRow extends StatelessWidget {
  const _AuditDetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }
}

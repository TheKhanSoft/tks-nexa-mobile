import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/regularization_request_bottom_sheet.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/shift_detail_bottom_sheet.dart';

/// Attendance History page body.
/// The app-bar and bottom navigation are provided by the parent shell.
class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(attendanceHistoryFilterProvider);
    final historyAsync = ref.watch(attendanceHistoryResponseProvider);
    final is24Hour =
        ref.watch(appPreferencesProvider).value?.use24HourTime ?? false;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          final _ = await ref.refresh(attendanceHistoryResponseProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          const _FilterBar(),
          const SizedBox(height: 16),
          historyAsync.when(
            loading: () => const _HistoryHeaderLoading(),
            error: (err, stack) => _HistoryErrorCard(
              message: 'Unable to load attendance history.',
              onRetry: () =>
                  ref.invalidate(attendanceHistoryResponseProvider),
            ),
            data: (history) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HistoryContent(
                  records: history.records,
                  serverSummary: history.summary,
                  fromDate: filterState.fromDate,
                  toDate: filterState.toDate,
                  is24Hour: is24Hour,
                ),
                const SizedBox(height: 24),
                const _RegularizationButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(attendanceHistoryFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: AttendanceDateFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = AttendanceDateFilter.values[index];
          final isSelected = filterState.filter == item;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
                  : const <BoxShadow>[],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: Key('filter_${item.name}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () async {
                  if (item == AttendanceDateFilter.custom) {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: filterState.fromDate,
                        end: filterState.toDate,
                      ),
                    );
                    if (range != null) {
                      ref
                          .read(attendanceHistoryFilterProvider.notifier)
                          .setCustomRange(
                        range.start,
                        DateTime(range.end.year, range.end.month,
                            range.end.day, 23, 59, 59),
                      );
                    }
                  } else {
                    ref
                        .read(attendanceHistoryFilterProvider.notifier)
                        .setFilter(item);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.onPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.records,
    this.serverSummary,
    required this.fromDate,
    required this.toDate,
    required this.is24Hour,
  });

  final List<AttendanceRecord> records;
  final AttendanceSummary? serverSummary;
  final DateTime fromDate;
  final DateTime toDate;
  final bool is24Hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final summary = _HistorySummary(records, serverSummary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimesheetCard(
          fromDate: fromDate,
          toDate: toDate,
          summary: summary,
        ),
        const SizedBox(height: 16),
        _RhythmCard(records: records),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.mobileAttendanceLog),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.phonelink_setup_rounded, size: 18),
          label: const Text('View Mobile Capture & Match Log', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        // Feed header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Activity Feed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${records.length} '
                    '${records.length == 1 ? 'Shift' : 'Shifts'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Records
        if (records.isEmpty)
          const _EmptyHistoryCard()
        else
          for (int i = 0; i < records.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _DailyActivityTile(record: records[i], is24Hour: is24Hour),
          ],
        const SizedBox(height: 20),
        _MilestoneBanner(ratePercent: summary.ratePercent),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers — all computed from real record fields, nothing hard-coded
// ─────────────────────────────────────────────────────────────────────────────

class _HistorySummary {
  _HistorySummary(List<AttendanceRecord> records, [AttendanceSummary? serverSummary])
      : presentCount = (serverSummary != null && serverSummary.present > 0)
            ? serverSummary.present
            : records.where((r) => r.isPresent || r.isLate || r.isHalfDay || r.isOfficialDuty).length,
        lateCount = (serverSummary != null && serverSummary.late > 0)
            ? serverSummary.late
            : records.where((r) => r.isLate).length,
        leaveCount = (serverSummary != null && serverSummary.onLeave > 0)
            ? serverSummary.onLeave
            : records.where((r) => r.isOnLeave).length,
        workingDays = math.max(
          (serverSummary != null && serverSummary.totalWorkingDays > 0)
              ? serverSummary.totalWorkingDays
              : records.where((r) => !r.isOffDay && !r.isFutureOrUpcoming && !r.date.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59))).length,
          (serverSummary != null && serverSummary.present > 0)
              ? serverSummary.present
              : records.where((r) => r.isPresent || r.isLate || r.isHalfDay || r.isOfficialDuty).length,
        ),
        totalMinutes = records.fold<int>(
          0,
          (sum, r) => sum + _parseMins(r.formattedNetDuration),
        ),
        workedDays = records
            .where((r) => _parseMins(r.formattedNetDuration) > 0)
            .length;

  final int workingDays;
  final int presentCount;
  final int lateCount;
  final int leaveCount;
  final int totalMinutes;
  final int workedDays;

  int get ratePercent => workingDays > 0
      ? math.min(100, ((presentCount / workingDays) * 100).round())
      : (presentCount > 0 ? 100 : 0);

  /// e.g. "168h 45m" — derived from summing each record's net duration.
  String get productiveLabel =>
      totalMinutes > 0 ? _fmtMins(totalMinutes) : '--';

  /// e.g. "Avg 8h 26m / day"
  String get avgLabel => workedDays > 0
      ? 'Avg ${_fmtMins(totalMinutes ~/ workedDays)} / day'
      : 'No hours logged yet';
}

/// Parses "8h 44m", "4h 15m", "1:30", etc. → minutes. Returns 0 on failure.
int _parseMins(String text) {
  if (text.isEmpty || text == '--' || text == '--:--') return 0;
  final h = RegExp(r'(\d+)\s*h').firstMatch(text);
  final m = RegExp(r'(\d+)\s*m').firstMatch(text);
  if (h != null || m != null) {
    return (int.tryParse(h?.group(1) ?? '') ?? 0) * 60 +
        (int.tryParse(m?.group(1) ?? '') ?? 0);
  }
  // HH:MM colon format fallback
  final clock = RegExp(r'^(\d+):(\d{2})').firstMatch(text.trim());
  if (clock != null) {
    return int.parse(clock.group(1)!) * 60 + int.parse(clock.group(2)!);
  }
  return 0;
}

/// Minutes → "Xh Ym"
String _fmtMins(int mins) =>
    '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';

/// DateTime → "Jan 5" (day-of-month, no leading zero)
String _shortDate(DateTime d) {
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${mo[d.month - 1]} ${d.day}';
}

/// Builds the fully-visible period label from filter boundaries.
/// Same year  → "Jan 1 – Jan 31, 2025"
/// Cross year → "Dec 28, 2024 – Jan 5, 2025"
String _periodLabel(DateTime from, DateTime to) {
  if (from.year == to.year) {
    return '${_shortDate(from)} – ${_shortDate(to)}, ${from.year}';
  }
  return '${_shortDate(from)}, ${from.year} – ${_shortDate(to)}, ${to.year}';
}

/// Unique int key for a date (used to index rhythm-strip records).
int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

// ─────────────────────────────────────────────────────────────────────────────
// Timesheet card
// ─────────────────────────────────────────────────────────────────────────────

class _TimesheetCard extends StatelessWidget {
  const _TimesheetCard({
    required this.fromDate,
    required this.toDate,
    required this.summary,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final _HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return _Surface(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period row — no truncation; text wraps if needed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIMESHEET PERIOD',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Full from–to date, no ellipsis, no maxLines cap.
                    Text(
                      _periodLabel(fromDate, toDate),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                color: _SC.success,
                label: '${summary.ratePercent}% On-Time',
                icon: Icons.verified_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Productive time + Working days
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatTile(
                  title: 'Productive Time',
                  value: summary.productiveLabel,
                  caption: summary.avgLabel,
                  tint: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  title: 'Working Days',
                  value: '${summary.workingDays} Days',
                  caption: '${summary.presentCount} Days Present',
                  captionColor: _SC.success,
                  tint: cs.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Late / Leave chips
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  color: _SC.warning,
                  label: 'Late/Early: ${summary.lateCount} '
                      '${summary.lateCount == 1 ? 'Day' : 'Days'}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricChip(
                  color: _SC.leave,
                  label: 'Leave/Off: ${summary.leaveCount} '
                      '${summary.leaveCount == 1 ? 'Day' : 'Days'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.caption,
    required this.tint,
    this.captionColor,
  });

  final String title;
  final String value;
  final String caption;
  final Color tint;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: captionColor ?? cs.onSurfaceVariant,
              fontWeight:
              captionColor != null ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly rhythm strip
// ─────────────────────────────────────────────────────────────────────────────

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.records});

  final List<AttendanceRecord> records;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Pin the strip to the Mon–Sun week that contains the most-recent record.
    final latest = records.isEmpty
        ? DateTime.now()
        : records.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final monday = DateTime(
        latest.year, latest.month, latest.day - (latest.weekday - 1));
    final byDay = {for (final r in records) _dayKey(r.date): r};
    final todayKey = _dayKey(DateTime.now());

    return _Surface(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Attendance Rhythm',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              Text(
                'Mon – Sun',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // spaceAround distributes the 7 fixed-width day bubbles evenly.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day =
              DateTime(monday.year, monday.month, monday.day + i);
              final record = byDay[_dayKey(day)];
              final statusColor = record == null
                  ? null
                  : _StatusStyle.of(record.status, cs).color;
              return _RhythmDay(
                label: _dayLabels[i],
                dateNum: day.day,
                statusColor: statusColor,
                isToday: _dayKey(day) == todayKey,
              );
            }),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: const [
              _LegendDot(color: _SC.success, label: 'On-Time'),
              _LegendDot(color: _SC.warning, label: 'Late Arrival'),
              _LegendDot(color: _SC.leave, label: 'Approved Leave'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RhythmDay extends StatelessWidget {
  const _RhythmDay({
    required this.label,
    required this.dateNum,
    this.statusColor,
    this.isToday = false,
  });

  final String label;
  final int dateNum;
  final Color? statusColor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = statusColor;
    final hasStatus = c != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasStatus
                ? c.withValues(alpha: 0.18)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: cs.primary, width: 2)
                : null,
          ),
          child: Text(
            '$dateNum',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: hasStatus
                  ? c
                  : cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: hasStatus ? c : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 5),
        Text(label,
            style:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily activity tile
// ─────────────────────────────────────────────────────────────────────────────

class _DailyActivityTile extends StatelessWidget {
  const _DailyActivityTile({
    required this.record,
    required this.is24Hour,
  });

  final AttendanceRecord record;
  final bool is24Hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final style = _StatusStyle.of(record.status, cs);

    final inTime = record.firstInFormatted ?? record.firstIn ?? '--:--';
    final outTime = record.lastOutFormatted ?? record.lastOut ?? '--:--';
    // Leave records label the third cell "Worked", not "Net Duration".
    final durationLabel = record.isOnLeave ? 'Worked' : 'Net Duration';

    const radius = BorderRadius.all(Radius.circular(22));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: style.color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured left accent bar — stretches to the card's full height.
                Container(width: 5, color: style.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day name + status badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (record.photoUrl != null && record.photoUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: style.color.withValues(alpha: 0.15),
                                  child: Image.network(
                                    record.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: style.color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record.dayName}, ${_shortDate(record.date)}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        style.placeIcon,
                                        size: 13,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          record.locationName ??
                                              style.placeFallback,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status pill now always carries its icon.
                            _Pill(
                              color: style.color,
                              label: style.label,
                              icon: style.icon,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Punch-time panel
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TimeCell(
                                  label: 'Punch In',
                                  value: inTime,
                                  // Late punch-in renders in amber.
                                  valueColor:
                                  record.isLate ? _SC.warning : null,
                                ),
                              ),
                              Expanded(
                                child: _TimeCell(
                                  label: 'Punch Out',
                                  value: outTime,
                                ),
                              ),
                              Expanded(
                                child: _TimeCell(
                                  label: durationLabel,
                                  value: record.formattedNetDuration,
                                  valueColor: cs.primary,
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 11),
                        // View punch & location — shown on every tile.
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () =>
                                ShiftDetailBottomSheet.show(context, record),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: cs.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View Punch & Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment:
      alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Milestone banner
// ─────────────────────────────────────────────────────────────────────────────

class _MilestoneBanner extends StatelessWidget {
  const _MilestoneBanner({required this.ratePercent});

  final int ratePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onTrack = ratePercent >= 90;
    final message = onTrack
        ? 'You are maintaining an outstanding $ratePercent% on-time record '
        'this period. Keep it above 90% to earn the monthly consistency badge!'
        : 'You are at $ratePercent% on-time this period. '
        'Reach 90% to earn the monthly consistency badge.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_graph_rounded, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Punctuality Score Milestone',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _RegularizationButton extends StatelessWidget {
  const _RegularizationButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: () => RegularizationRequestBottomSheet.show(context),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        icon: const Icon(Icons.edit_calendar_rounded, size: 20),
        label: const Text(
          'Regularization / Missed Punch Request',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

/// Themed card surface used by the timesheet card and rhythm strip.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border:
        Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Rounded status badge — icon when provided, coloured dot otherwise.
class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label, this.icon});

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status semantics
// ─────────────────────────────────────────────────────────────────────────────

/// Shared colour constants used by every status-aware widget.
abstract final class _SC {
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const leave   = Color(0xFF8B5CF6);
  static const duty    = Color(0xFF2563EB);
  static const danger  = Color(0xFFEF4444);
  static const neutral = Color(0xFF6B7280);
}

/// Maps a status string → colour + label + icon + location fallback.
/// Half-day leave is resolved inside the "leave" branch so a single
/// `s.contains('leave')` check covers all leave variants cleanly.
class _StatusStyle {
  const _StatusStyle({
    required this.color,
    required this.label,
    required this.icon,
    required this.placeIcon,
    required this.placeFallback,
  });

  final Color color;
  final String label;
  final IconData icon;
  final IconData placeIcon;
  final String placeFallback;

  factory _StatusStyle.of(String status, ColorScheme cs) {
    final s = status.toLowerCase();

    if (s.contains('present') ||
        s.contains('accepted') ||
        s.contains('matched')) {
      return const _StatusStyle(
        color: _SC.success,
        label: 'Present - On Time',
        icon: Icons.check_circle_rounded,
        placeIcon: Icons.business_rounded,
        placeFallback: 'HQ Office',
      );
    }
    if (s.contains('late')) {
      return const _StatusStyle(
        color: _SC.warning,
        label: 'Late Arrival',
        icon: Icons.access_time_filled_rounded,
        placeIcon: Icons.business_rounded,
        placeFallback: 'HQ Office',
      );
    }
    if (s.contains('leave')) {
      final isHalf = s.contains('half');
      return _StatusStyle(
        color: _SC.leave,
        label: isHalf ? 'Half Day Leave' : 'Approved Leave',
        icon: Icons.flight_takeoff_rounded,
        placeIcon: Icons.event_available_rounded,
        placeFallback:
        isHalf ? 'Approved leave (1st Half)' : 'Approved leave',
      );
    }
    if (s.contains('duty')) {
      return const _StatusStyle(
        color: _SC.duty,
        label: 'Official Duty',
        icon: Icons.business_center_rounded,
        placeIcon: Icons.business_center_rounded,
        placeFallback: 'On official duty',
      );
    }
    if (s.contains('absent') || s.contains('rejected')) {
      return const _StatusStyle(
        color: _SC.danger,
        label: 'Absent',
        icon: Icons.cancel_rounded,
        placeIcon: Icons.event_busy_rounded,
        placeFallback: 'No punch recorded',
      );
    }
    if (s.contains('wfh') ||
        s.contains('remote') ||
        s.contains('home')) {
      return _StatusStyle(
        color: cs.primary,
        label: 'Remote WFH',
        icon: Icons.home_work_rounded,
        placeIcon: Icons.home_work_rounded,
        placeFallback: 'Remote Geofence',
      );
    }
    return const _StatusStyle(
      color: _SC.neutral,
      label: 'Scheduled Shift',
      icon: Icons.schedule_rounded,
      placeIcon: Icons.business_rounded,
      placeFallback: 'HQ Office',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / error / empty states
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryHeaderLoading extends StatelessWidget {
  const _HistoryHeaderLoading();

  @override
  Widget build(BuildContext context) {
    return const _Surface(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Loading PulseWork timesheet records...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorCard extends StatelessWidget {
  const _HistoryErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Surface(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 44),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Timesheet'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Surface(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          const Text('No Recorded Shifts',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'No timesheet punch logs found for this period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/punch_detail.dart';

enum AttendanceDateFilter {
  thisWeek('This Week', 'this_week'),
  lastWeek('Last Week', 'last_week'),
  thisMonth('This Month', 'this_month'),
  lastMonth('Last Month', 'last_month'),
  custom('Custom Range', 'custom');

  const AttendanceDateFilter(this.label, this.apiKey);
  final String label;
  final String apiKey;
}

class AttendanceHistoryFilterState {
  const AttendanceHistoryFilterState({
    required this.filter,
    required this.fromDate,
    required this.toDate,
  });

  final AttendanceDateFilter filter;
  final DateTime fromDate;
  final DateTime toDate;

  AttendanceHistoryFilterState copyWith({
    AttendanceDateFilter? filter,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return AttendanceHistoryFilterState(
      filter: filter ?? this.filter,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

final attendanceHistoryFilterProvider = NotifierProvider<
    AttendanceHistoryFilterController, AttendanceHistoryFilterState>(
  AttendanceHistoryFilterController.new,
);

class AttendanceHistoryFilterController
    extends Notifier<AttendanceHistoryFilterState> {
  @override
  AttendanceHistoryFilterState build() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return AttendanceHistoryFilterState(
      filter: AttendanceDateFilter.thisWeek,
      fromDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void setFilter(AttendanceDateFilter filter) {
    final now = DateTime.now();
    DateTime from;
    DateTime to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (filter) {
      case AttendanceDateFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        break;
      case AttendanceDateFilter.lastWeek:
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        final startOfLastWeek =
            endOfLastWeek.subtract(const Duration(days: 6));
        from = DateTime(
          startOfLastWeek.year,
          startOfLastWeek.month,
          startOfLastWeek.day,
        );
        to = DateTime(
          endOfLastWeek.year,
          endOfLastWeek.month,
          endOfLastWeek.day,
          23,
          59,
          59,
        );
        break;
      case AttendanceDateFilter.thisMonth:
        from = DateTime(now.year, now.month, 1);
        break;
      case AttendanceDateFilter.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        from = lastMonthDate;
        final endOfLastMonth = DateTime(now.year, now.month, 0);
        to = DateTime(
          endOfLastMonth.year,
          endOfLastMonth.month,
          endOfLastMonth.day,
          23,
          59,
          59,
        );
        break;
      case AttendanceDateFilter.custom:
        from = state.fromDate;
        to = state.toDate;
        break;
    }

    state = AttendanceHistoryFilterState(
      filter: filter,
      fromDate: from,
      toDate: to,
    );
  }

  void setCustomRange(DateTime from, DateTime to) {
    state = AttendanceHistoryFilterState(
      filter: AttendanceDateFilter.custom,
      fromDate: from,
      toDate: to,
    );
  }
}

final attendanceHistoryResponseProvider =
    FutureProvider<AttendanceHistoryResponse>((ref) async {
  final filterState = ref.watch(attendanceHistoryFilterProvider);
  final api = ref.watch(mobileAttendanceApiProvider);
  return api.fetchAttendanceHistory(
    period: filterState.filter.apiKey,
    fromDate: filterState.fromDate,
    toDate: filterState.toDate,
  );
});

final punchDetailProvider =
    FutureProvider.family<PunchDetailData, String>((ref, date) async {
  final api = ref.watch(mobileAttendanceApiProvider);
  return api.fetchPunchDetail(date: date);
});

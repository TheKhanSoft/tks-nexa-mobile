import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';

class AttendanceRecordDto {
  const AttendanceRecordDto._();

  static AttendanceHistoryResponse parseResponse(Object? response) {
    if (response == null) {
      return const AttendanceHistoryResponse(
        periodLabel: 'Attendance Records',
        summary: AttendanceSummary(),
        records: [],
      );
    }

    try {
      final root = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      final data = root['data'] is Map ? Map<String, dynamic>.from(root['data']) : root;

      final periodMap = data['period'] is Map ? Map<String, dynamic>.from(data['period']) : null;
      final periodLabel = _string(periodMap?['label'], fallback: 'Attendance History');

      final summaryMap = data['summary'] is Map ? Map<String, dynamic>.from(data['summary']) : null;
      var summary = summaryMap != null
          ? AttendanceSummary(
              totalDays: _int(summaryMap['total_days']),
              totalWorkingDays: _int(summaryMap['total_working_days']),
              present: _int(summaryMap['present']),
              absent: _int(summaryMap['absent']),
              late: _int(summaryMap['late']),
              halfDay: _int(summaryMap['half_day']),
              holidays: _int(summaryMap['holidays']),
              onLeave: _int(summaryMap['on_leave']),
              officialDuty: _int(summaryMap['official_duty']),
            )
          : const AttendanceSummary();

      List<dynamic>? rawRecords;
      final dailyRecords = data['daily_records'] ?? data['records'] ?? data['data'];
      if (dailyRecords is List) {
        rawRecords = dailyRecords;
      } else if (response is List) {
        rawRecords = response;
      }

      final parsedList = (rawRecords ?? const [])
          .whereType<Map>()
          .map((item) => fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);

      // Group and collapse records by date (Strictly ONE card per day)
      final groupedMap = <String, AttendanceRecord>{};
      for (final record in parsedList) {
        final dateKey = record.date.toIso8601String().split('T').first;
        if (!groupedMap.containsKey(dateKey)) {
          groupedMap[dateKey] = record;
        } else {
          final existing = groupedMap[dateKey]!;
          final earliestIn = _compareTimes(existing.firstInFormatted, record.firstInFormatted, isEarliest: true);
          final latestOut = _compareTimes(existing.lastOutFormatted, record.lastOutFormatted, isEarliest: false);
          groupedMap[dateKey] = AttendanceRecord(
            id: existing.id,
            date: existing.date,
            dayName: existing.dayName,
            status: existing.isPresent ? existing.status : record.status,
            firstIn: existing.firstIn,
            firstInFormatted: earliestIn,
            lastOut: latestOut,
            lastOutFormatted: latestOut,
            shiftName: existing.shiftName,
            photoUrl: record.photoUrl ?? existing.photoUrl,
            locationName: record.locationName ?? existing.locationName,
            deviceLabel: record.deviceLabel ?? existing.deviceLabel,
            deviceModel: record.deviceModel ?? existing.deviceModel,
            platform: record.platform ?? existing.platform,
            latitude: record.latitude ?? existing.latitude,
            longitude: record.longitude ?? existing.longitude,
            trustScore: record.trustScore ?? existing.trustScore,
          );
        }
      }

      final records = groupedMap.values.toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

      // Dynamically compute accurate summary statistics from parsed records if API summary was empty
      if (summary.present == 0 && summary.absent == 0 && summary.late == 0 && records.isNotEmpty) {
        var p = 0, a = 0, l = 0, leave = 0, duty = 0, workDays = 0;
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        for (final r in records) {
          final isPastOrToday = !r.date.isAfter(endOfToday);
          if (!r.isOffDay && !r.isFutureOrUpcoming && isPastOrToday) {
            workDays++;
          }
          if (r.isPresent) {
            p++;
          } else if (r.isLate) {
            p++;
            l++;
          } else if (r.isHalfDay) {
            p++;
          } else if (r.isOnLeave) {
            leave++;
          } else if (r.isOfficialDuty) {
            p++;
            duty++;
          } else if (r.isAbsent && isPastOrToday) {
            a++;
          }
        }
        if (p > workDays) {
          workDays = p;
        }
        summary = AttendanceSummary(
          totalDays: records.length,
          totalWorkingDays: workDays,
          present: p,
          absent: a,
          late: l,
          onLeave: leave,
          officialDuty: duty,
        );
      }

      return AttendanceHistoryResponse(
        periodLabel: periodLabel,
        summary: summary,
        records: records,
      );
    } catch (_) {
      return const AttendanceHistoryResponse(
        periodLabel: 'Attendance Records',
        summary: AttendanceSummary(),
        records: [],
      );
    }
  }

  static AttendanceRecord fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'] ?? map['attendance_date'] ?? map['created_at'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) ?? DateTime.now() : DateTime.now();

    final deviceMap = map['device_captured_with'] is Map
        ? Map<String, dynamic>.from(map['device_captured_with'])
        : (map['device'] is Map ? Map<String, dynamic>.from(map['device']) : null);

    final coordsMap = deviceMap?['coordinates'] is Map
        ? Map<String, dynamic>.from(deviceMap!['coordinates'])
        : null;

    final status = _string(map['status'], fallback: 'Present');
    final firstIn = _string(map['first_in'], fallback: _string(map['punch_in']));
    final firstInFormatted = _string(map['first_in_formatted'], fallback: _string(map['check_in_time']));
    final lastOut = _string(map['last_out'], fallback: _string(map['punch_out']));
    final lastOutFormatted = _string(map['last_out_formatted'], fallback: _string(map['check_out_time']));

    return AttendanceRecord(
      id: _string(map['id'], fallback: date.toIso8601String().split('T').first),
      date: date,
      dayName: _string(map['day_name'], fallback: _dayName(date)),
      status: status,
      firstIn: firstIn.isNotEmpty ? firstIn : null,
      firstInFormatted: firstInFormatted.isNotEmpty ? firstInFormatted : (firstIn.isNotEmpty ? firstIn : null),
      lastOut: lastOut.isNotEmpty ? lastOut : null,
      lastOutFormatted: lastOutFormatted.isNotEmpty ? lastOutFormatted : (lastOut.isNotEmpty ? lastOut : null),
      shiftName: _string(map['shift_name'], fallback: _string(map['shift'], fallback: 'General Shift')),
      photoUrl: _string(
        map['photo_url'],
        fallback: _string(
          map['snapshot_url'],
          fallback: _string(
            map['evidence_photo'],
            fallback: _string(map['captured_photo_url']),
          ),
        ),
      ).isNotEmpty
          ? _string(
              map['photo_url'],
              fallback: _string(
                map['snapshot_url'],
                fallback: _string(
                  map['evidence_photo'],
                  fallback: _string(map['captured_photo_url']),
                ),
              ),
            )
          : null,
      locationName: _string(map['location_name'], fallback: _string(map['location'])),
      deviceLabel: _string(deviceMap?['display_label'], fallback: _string(deviceMap?['model'])),
      deviceModel: _string(deviceMap?['model']),
      platform: _string(deviceMap?['platform']),
      latitude: _double(coordsMap?['latitude']),
      longitude: _double(coordsMap?['longitude']),
      trustScore: _int(map['trust_score'], fallback: _int(map['trust'])),
    );
  }

  static String? _compareTimes(String? t1, String? t2, {required bool isEarliest}) {
    if (t1 == null || t1 == '--:--' || t1 == 'Pending') return t2;
    if (t2 == null || t2 == '--:--' || t2 == 'Pending') return t1;
    return isEarliest ? (t1.compareTo(t2) <= 0 ? t1 : t2) : (t1.compareTo(t2) >= 0 ? t1 : t2);
  }

  static String _dayName(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  static String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

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

          // Collect all punch timestamps available across both records
          final allTimes = <String>[
            if (existing.firstInFormatted != null && existing.firstInFormatted != '--:--' && existing.firstInFormatted != 'Pending') existing.firstInFormatted!,
            if (existing.lastOutFormatted != null && existing.lastOutFormatted != '--:--' && existing.lastOutFormatted != 'Pending') existing.lastOutFormatted!,
            if (record.firstInFormatted != null && record.firstInFormatted != '--:--' && record.firstInFormatted != 'Pending') record.firstInFormatted!,
            if (record.lastOutFormatted != null && record.lastOutFormatted != '--:--' && record.lastOutFormatted != 'Pending') record.lastOutFormatted!,
          ];

          String? earliestIn = existing.firstInFormatted ?? record.firstInFormatted;
          String? latestOut = record.lastOutFormatted ?? existing.lastOutFormatted;

          if (allTimes.length >= 2) {
            allTimes.sort((a, b) {
              final da = AttendanceRecord.parseTime(a);
              final db = AttendanceRecord.parseTime(b);
              if (da == null || db == null) return a.compareTo(b);
              return da.compareTo(db);
            });
            earliestIn = allTimes.first;
            latestOut = allTimes.last;
          }

          final combinedCount = existing.verificationCount +
              (record.verificationCount > 0 ? record.verificationCount : 1);
          final hasMultiple = combinedCount >= 2 || allTimes.length >= 2;
          final effectiveOut = hasMultiple ? latestOut : null;

          final combinedIsShiftEnded = existing.isShiftEnded || record.isShiftEnded;
          final combinedIsLate = !combinedIsShiftEnded && (existing.isLate || record.isLate);
          final combinedStatus = combinedIsShiftEnded
              ? 'Shift Ended'
              : (combinedIsLate
                  ? 'Late'
                  : (existing.isPresent ? existing.status : record.status));

          groupedMap[dateKey] = AttendanceRecord(
            id: existing.id,
            date: existing.date,
            dayName: existing.dayName,
            status: combinedStatus,
            isLate: combinedIsLate,
            isShiftEnded: combinedIsShiftEnded,
            firstIn: existing.firstIn ?? record.firstIn,
            firstInFormatted: earliestIn,
            lastOut: effectiveOut,
            lastOutFormatted: effectiveOut,
            shiftName: existing.shiftName,
            photoUrl: record.photoUrl ?? existing.photoUrl,
            locationName: record.locationName ?? existing.locationName,
            deviceLabel: record.deviceLabel ?? existing.deviceLabel,
            deviceModel: record.deviceModel ?? existing.deviceModel,
            platform: record.platform ?? existing.platform,
            latitude: record.latitude ?? existing.latitude,
            longitude: record.longitude ?? existing.longitude,
            trustScore: record.trustScore ?? existing.trustScore,
            verificationCount: combinedCount,
            verificationCode: existing.verificationCode ?? record.verificationCode,
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
          if (r.isLate) {
            p++;
            l++;
          } else if (r.isPresent) {
            p++;
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

    final rawIsLate = map['is_late'] == true ||
        map['late'] == true ||
        map['isLate'] == true ||
        map['is_late'] == 1 ||
        map['late'] == 1 ||
        _string(map['status']).toLowerCase().contains('late') ||
        _string(map['status_label']).toLowerCase().contains('late');

    final isWeekendDay = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isExplicitWeekend = map['is_weekend'] == true ||
        map['weekend'] == true ||
        map['is_off'] == true ||
        map['is_off_day'] == true ||
        _string(map['status']).toLowerCase().contains('weekend') ||
        _string(map['status']).toLowerCase().contains('weekly off') ||
        _string(map['status']).toLowerCase().contains('rest day');
    final isExplicitHoliday = map['is_holiday'] == true ||
        map['holiday'] == true ||
        _string(map['status']).toLowerCase().contains('holiday') ||
        _string(map['status']).toLowerCase().contains('gazetted');
    final isExplicitDuty = map['is_official_duty'] == true ||
        map['official_duty'] == true ||
        map['is_duty'] == true ||
        _string(map['status']).toLowerCase().contains('duty') ||
        _string(map['status']).toLowerCase().contains('official') ||
        _string(map['status']).toLowerCase().contains('od');

    var isLateResolved = rawIsLate;
    var status = _string(map['status']);
    if (status.isEmpty) {
      if (rawIsLate) {
        status = 'Late';
      } else if (isExplicitDuty) {
        status = 'Official Duty';
      } else if (isExplicitHoliday) {
        status = 'Holiday';
      } else if (isExplicitWeekend || isWeekendDay) {
        status = 'Weekend';
      } else {
        status = 'Present';
      }
    }
    final verificationCount = _int(map['verification_count'], fallback: _int(map['total_scans']));
    final rawScans = map['scans'] is List ? (map['scans'] as List).whereType<Map>().toList() : <Map>[];

    var firstIn = _string(map['first_in'], fallback: _string(map['punch_in']));
    var firstInFormatted = _string(map['first_in_formatted'], fallback: _string(map['check_in_time']));
    var rawLastOut = _string(map['last_out'], fallback: _string(map['punch_out']));
    var rawLastOutFormatted = _string(map['last_out_formatted'], fallback: _string(map['check_out_time']));

    // If map is a single raw punch log (e.g. from data['data']), extract its time as the first punch
    final singleLogTime = _string(map['formatted_time'], fallback: _string(map['time']));
    final singleLogRawTime = _string(map['timestamp'], fallback: _string(map['time_raw']));
    if (firstInFormatted.isEmpty && singleLogTime.isNotEmpty) {
      firstInFormatted = singleLogTime;
      firstIn = singleLogRawTime.isNotEmpty ? singleLogRawTime : singleLogTime;
    }

    // If scans list is provided and has >= 2 punches, guarantee check-in and check-out are captured
    if (rawScans.length >= 2) {
      final firstScan = rawScans.first;
      final lastScan = rawScans.last;
      firstInFormatted = _string(firstScan['time'], fallback: firstInFormatted);
      firstIn = _string(firstScan['time_raw'], fallback: firstIn);
      rawLastOutFormatted = _string(lastScan['time'], fallback: rawLastOutFormatted);
      rawLastOut = _string(lastScan['time_raw'], fallback: rawLastOut);
    }

    // Detect Shift End time:
    final shiftStartStr = _string(map['shift_start']);
    final rawShiftTiming = _string(
      map['shift_timing'],
      fallback: _string(
        map['shift_end'],
        fallback: _string(
          map['shift_end_time'],
          fallback: _string(map['end_time']),
        ),
      ),
    );

    String resolvedShiftEnd = '';
    if (rawShiftTiming.contains('-')) {
      final parts = rawShiftTiming.split('-');
      if (parts.length >= 2) {
        resolvedShiftEnd = parts[1].trim();
      }
    } else {
      resolvedShiftEnd = rawShiftTiming.trim();
    }
    if (resolvedShiftEnd.isEmpty) {
      // General Shift standard end time cutoff is 04:00 PM
      resolvedShiftEnd = '04:00 PM';
    }

    final checkInTimeStr = firstInFormatted.isNotEmpty ? firstInFormatted : firstIn;
    final firstInDt = checkInTimeStr.isNotEmpty ? AttendanceRecord.parseTime(checkInTimeStr) : null;
    final shiftEndDt = resolvedShiftEnd.isNotEmpty ? AttendanceRecord.parseTime(resolvedShiftEnd) : null;

    bool isShiftEndedResolved = false;
    final rawStatusLower = _string(map['status']).toLowerCase();

    if (rawStatusLower.contains('shift ended') || rawStatusLower.contains('outside shift')) {
      isShiftEndedResolved = true;
    } else if (shiftEndDt != null && firstInDt != null) {
      // If check-in happened at or after the shift end time
      if (!firstInDt.isBefore(shiftEndDt)) {
        isShiftEndedResolved = true;
      }
    }

    if (isShiftEndedResolved) {
      isLateResolved = false;
      status = 'Shift Ended';
    } else if (!isLateResolved) {
      final graceMinutes = _int(map['grace_period_minutes'], fallback: 15);
      if (shiftStartStr.isNotEmpty && firstInDt != null) {
        final shiftStartDt = AttendanceRecord.parseTime(shiftStartStr);
        if (shiftStartDt != null) {
          final graceCutoff = shiftStartDt.add(Duration(minutes: graceMinutes));
          if (firstInDt.isAfter(graceCutoff)) {
            isLateResolved = true;
          }
        }
      }
    }

    final sLower = status.toLowerCase();
    if (!isShiftEndedResolved) {
      if (isLateResolved && sLower == 'present') {
        status = 'Late';
      } else if (isExplicitHoliday || sLower.contains('holiday') || sLower.contains('gazetted')) {
        status = 'Holiday';
      } else if (isExplicitDuty || sLower.contains('duty') || sLower.contains('official')) {
        status = 'Official Duty';
      } else if (isExplicitWeekend || (isWeekendDay && (firstIn.isEmpty || sLower == 'scheduled' || sLower == 'scheduled shift' || sLower == 'absent'))) {
        status = 'Weekend';
      }
    }

    final hasMultiplePunches = verificationCount >= 2 || rawScans.length >= 2;

    // Check Out resolution:
    // When multiple punches are available, the last punch is unconditionally considered as Check Out.
    // If only one punch occurred (no checkout yet), checkout must be null (rendered as --:-- in the UI).
    String? lastOut;
    String? lastOutFormatted;

    if (hasMultiplePunches) {
      if (rawLastOutFormatted.isNotEmpty && rawLastOutFormatted != '--:--' && rawLastOutFormatted != 'Pending') {
        lastOutFormatted = rawLastOutFormatted;
        lastOut = rawLastOut.isNotEmpty ? rawLastOut : rawLastOutFormatted;
      } else if (rawLastOut.isNotEmpty && rawLastOut != '--:--' && rawLastOut != 'Pending') {
        lastOut = rawLastOut;
        lastOutFormatted = rawLastOut;
      }
    } else {
      // If only 1 punch occurred, check if there's an explicit distinct last_out
      final isDistinctOut = rawLastOutFormatted.isNotEmpty &&
          rawLastOutFormatted != firstInFormatted &&
          rawLastOutFormatted != '--:--' &&
          rawLastOutFormatted != 'Pending';
      if (isDistinctOut) {
        lastOutFormatted = rawLastOutFormatted;
        lastOut = rawLastOut.isNotEmpty ? rawLastOut : rawLastOutFormatted;
      }
    }

    final resolvedPhoto = _string(
      map['evidence_photo'],
      fallback: _string(
        map['captured_photo_url'],
        fallback: _string(
          map['punch_photo'],
          fallback: _string(
            map['punch_photo_url'],
            fallback: _string(
              map['snapshot_url'],
              fallback: _string(
                map['attendance_photo'],
                fallback: _string(
                  map['verification_photo'],
                  fallback: _string(
                    map['selfie_url'],
                    fallback: _string(
                      map['face_photo_url'],
                      fallback: _string(
                        map['snapshot_base64'],
                        fallback: _string(
                          map['photo_base64'],
                          fallback: _string(
                            map['face_snapshot'],
                            fallback: _string(
                              map['snapshot'],
                              fallback: _string(map['photo']),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return AttendanceRecord(
      id: _string(map['id'], fallback: date.toIso8601String().split('T').first),
      date: date,
      dayName: _string(map['day_name'], fallback: _dayName(date)),
      status: status,
      isLate: isLateResolved,
      isShiftEnded: isShiftEndedResolved,
      firstIn: firstIn.isNotEmpty ? firstIn : null,
      firstInFormatted: firstInFormatted.isNotEmpty ? firstInFormatted : (firstIn.isNotEmpty ? firstIn : null),
      lastOut: lastOut,
      lastOutFormatted: lastOutFormatted,
      shiftName: _string(map['shift_name'], fallback: _string(map['shift'], fallback: 'General Shift')),
      photoUrl: resolvedPhoto.isNotEmpty ? resolvedPhoto : null,
      locationName: _string(map['location_name'], fallback: _string(map['location'])),
      deviceLabel: _string(deviceMap?['display_label'], fallback: _string(deviceMap?['model'])),
      deviceModel: _string(deviceMap?['model']),
      platform: _string(deviceMap?['platform']),
      latitude: _double(coordsMap?['latitude']),
      longitude: _double(coordsMap?['longitude']),
      trustScore: _int(map['trust_score'], fallback: _int(map['trust'])),
      verificationCount: verificationCount > 0 ? verificationCount : (rawScans.isNotEmpty ? rawScans.length : 1),
      verificationCode: _string(map['verification_code']).isNotEmpty ? _string(map['verification_code']) : null,
    );
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

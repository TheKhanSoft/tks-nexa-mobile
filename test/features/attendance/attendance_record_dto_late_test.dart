import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/attendance_record_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';

void main() {
  group('AttendanceRecordDto & AttendanceRecord Late Arrival Resolution', () {
    test('resolves isLate and status correctly when is_late flag is true from API', () {
      final map = <String, dynamic>{
        'date': '2026-10-08',
        'status': 'Present',
        'is_late': true,
        'first_in': '08:32',
        'first_in_formatted': '08:32 AM',
        'shift_name': 'Morning Shift',
      };

      final record = AttendanceRecordDto.fromMap(map);

      expect(record.isLate, isTrue);
      expect(record.status, 'Late');
      expect(record.isPresent, isTrue);
    });

    test('deduces isLate from check-in time past shift start plus grace window', () {
      final map = <String, dynamic>{
        'date': '2026-10-08',
        'status': 'Present',
        'is_late': false,
        'first_in': '08:32',
        'first_in_formatted': '08:32 AM',
        'shift_start': '08:00',
        'grace_period_minutes': 15,
        'shift_name': 'Morning Shift',
      };

      final record = AttendanceRecordDto.fromMap(map);

      expect(record.isLate, isTrue);
      expect(record.status, 'Late');
    });

    test('retains on-time status when check-in is within grace period', () {
      final map = <String, dynamic>{
        'date': '2026-10-08',
        'status': 'Present',
        'is_late': false,
        'first_in': '08:10',
        'first_in_formatted': '08:10 AM',
        'shift_start': '08:00',
        'grace_period_minutes': 15,
        'shift_name': 'Morning Shift',
      };

      final record = AttendanceRecordDto.fromMap(map);

      expect(record.isLate, isFalse);
      expect(record.status, 'Present');
    });

    test('groups multiple records for same day and preserves late status', () {
      final response = {
        'data': {
          'daily_records': [
            {
              'date': '2026-10-08',
              'status': 'Present',
              'is_late': true,
              'first_in_formatted': '08:32 AM',
            },
            {
              'date': '2026-10-08',
              'status': 'Present',
              'is_late': false,
              'last_out_formatted': '05:00 PM',
            },
          ],
        },
      };

      final parsed = AttendanceRecordDto.parseResponse(response);
      expect(parsed.records.length, 1);

      final todayRecord = parsed.records.first;
      expect(todayRecord.isLate, isTrue);
      expect(todayRecord.status, 'Late');
      expect(todayRecord.firstInFormatted, '08:32 AM');
      expect(todayRecord.lastOutFormatted, '05:00 PM');
    });
  });
}

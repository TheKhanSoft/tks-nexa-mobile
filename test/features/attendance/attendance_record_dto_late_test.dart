import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/attendance_record_dto.dart';

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

    test('marks as Shift Ended and not Late Arrival when check-in is after shift ends', () {
      final map = <String, dynamic>{
        'date': '2026-10-09',
        'status': 'Present',
        'is_late': true,
        'first_in_formatted': '04:03 PM',
        'shift_start': '08:00 AM',
        'shift_end': '04:00 PM',
        'shift_name': 'General Shift',
      };

      final record = AttendanceRecordDto.fromMap(map);

      expect(record.isShiftEnded, isTrue);
      expect(record.isLate, isFalse);
      expect(record.status, 'Shift Ended');
      expect(record.formattedNetDuration, '--');
    });

    test('resolves Weekend on Saturday and Sunday when no punches are logged', () {
      final satMap = <String, dynamic>{
        'date': '2026-10-10', // Saturday
        'status': 'Scheduled',
      };
      final sunMap = <String, dynamic>{
        'date': '2026-10-11', // Sunday
        'status': 'Scheduled Shift',
      };

      final satRecord = AttendanceRecordDto.fromMap(satMap);
      final sunRecord = AttendanceRecordDto.fromMap(sunMap);

      expect(satRecord.isWeekend, isTrue);
      expect(satRecord.status, 'Weekend');
      expect(satRecord.isOffDay, isTrue);

      expect(sunRecord.isWeekend, isTrue);
      expect(sunRecord.status, 'Weekend');
      expect(sunRecord.isOffDay, isTrue);
    });

    test('resolves Holiday and Official Duty correctly', () {
      final holidayMap = <String, dynamic>{
        'date': '2026-10-14',
        'status': 'Holiday',
        'holiday_name': 'Independence Day',
      };
      final dutyMap = <String, dynamic>{
        'date': '2026-10-15',
        'status': 'Official Duty',
        'first_in_formatted': '09:00 AM',
      };

      final holidayRecord = AttendanceRecordDto.fromMap(holidayMap);
      final dutyRecord = AttendanceRecordDto.fromMap(dutyMap);

      expect(holidayRecord.isHoliday, isTrue);
      expect(holidayRecord.status, 'Holiday');
      expect(holidayRecord.isOffDay, isTrue);

      expect(dutyRecord.isOfficialDuty, isTrue);
      expect(dutyRecord.status, 'Official Duty');
      expect(dutyRecord.isOffDay, isFalse);
    });
  });
}

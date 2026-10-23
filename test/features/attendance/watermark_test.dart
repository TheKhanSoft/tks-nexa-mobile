import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_watermark_service.dart';

void main() {
  test('AttendanceWatermarkService generates watermarked image in shared mode', () async {
    const service = AttendanceWatermarkService();
    final bytes = await service.generateWatermarkedImage(
      verificationCode: '4E7D5140',
      timestamp: DateTime(2026, 9, 15, 8, 29, 59),
      latitude: 34.188177,
      longitude: 71.908437,
      username: 'kashif.awkum',
      employeeCode: 'AWK-001',
      orgName: 'awkum',
      mode: WatermarkMode.shared,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test('AttendanceWatermarkService generates watermarked image in downloaded mode', () async {
    const service = AttendanceWatermarkService();
    final bytes = await service.generateWatermarkedImage(
      verificationCode: '4E7D5140',
      timestamp: DateTime(2026, 9, 15, 8, 29, 59),
      latitude: 34.188177,
      longitude: 71.908437,
      username: 'kashif.awkum',
      employeeCode: 'AWK-001',
      orgName: 'awkum',
      mode: WatermarkMode.downloaded,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test('formatShareCaption produces expected WhatsApp caption', () {
    final caption = AttendanceWatermarkService.formatShareCaption(
      timestamp: DateTime(2026, 9, 15, 8, 29, 59),
      latitude: 34.188177,
      longitude: 71.908437,
      verificationCode: '4E7D5140',
    );

    expect(caption, contains('📅 2026-09-15 08:29:59'));
    expect(caption, contains('📌 34.188177, 71.908437'));
    expect(caption, contains('🔐 4E7D5140'));
  });

  test('formatTimestamp converts UTC timestamps to local device time', () {
    final utcTime = DateTime.utc(2026, 10, 22, 6, 23, 19);
    final expectedLocal = utcTime.toLocal();
    final expectedStr =
        '${expectedLocal.year}-${expectedLocal.month.toString().padLeft(2, '0')}-${expectedLocal.day.toString().padLeft(2, '0')} '
        '${expectedLocal.hour.toString().padLeft(2, '0')}:${expectedLocal.minute.toString().padLeft(2, '0')}:${expectedLocal.second.toString().padLeft(2, '0')}';

    final result = AttendanceWatermarkService.formatTimestamp(utcTime);
    expect(result, equals(expectedStr));
  });

  test('formatVerificationCode consistently hashes localized timestamp seed', () {
    final utcTime = DateTime.utc(2026, 10, 22, 6, 23, 19);
    final localTime = utcTime.toLocal();

    final codeFromUtc = AttendanceWatermarkService.formatVerificationCode(null, timestamp: utcTime);
    final codeFromLocal = AttendanceWatermarkService.formatVerificationCode(null, timestamp: localTime);

    expect(codeFromUtc, equals(codeFromLocal));
  });
}

class AttendanceSummary {
  const AttendanceSummary({
    this.totalDays = 0,
    this.totalWorkingDays = 0,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.halfDay = 0,
    this.holidays = 0,
    this.onLeave = 0,
    this.officialDuty = 0,
  });

  final int totalDays;
  final int totalWorkingDays;
  final int present;
  final int absent;
  final int late;
  final int halfDay;
  final int holidays;
  final int onLeave;
  final int officialDuty;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.dayName,
    required this.status,
    this.firstIn,
    this.firstInFormatted,
    this.lastOut,
    this.lastOutFormatted,
    this.shiftName = 'General Shift',
    this.photoUrl,
    this.locationName,
    this.deviceName,
    this.deviceLabel,
    this.deviceModel,
    this.platform,
    this.latitude,
    this.longitude,
    this.trustScore,
    this.verificationCount = 0,
  });

  final String id;
  final DateTime date;
  final String dayName;
  final String status;
  final String? firstIn;
  final String? firstInFormatted;
  final String? lastOut;
  final String? lastOutFormatted;
  final String shiftName;
  final String? photoUrl;
  final String? locationName;
  final String? deviceName;
  final String? deviceLabel;
  final String? deviceModel;
  final String? platform;
  final double? latitude;
  final double? longitude;
  final int? trustScore;
  final int verificationCount;

  bool get isPresent =>
      status.toLowerCase().contains('present') ||
      status.toLowerCase().contains('accepted') ||
      status.toLowerCase().contains('matched');
  bool get isLate => status.toLowerCase().contains('late');
  bool get isHalfDay => status.toLowerCase().contains('half');
  bool get isOnLeave => status.toLowerCase().contains('leave');
  bool get isOfficialDuty => status.toLowerCase().contains('duty');
  bool get isAbsent => status.toLowerCase().contains('absent');
  bool get isOffDay =>
      status.toLowerCase().contains('off') ||
      status.toLowerCase().contains('holiday') ||
      status.toLowerCase().contains('weekend');
  bool get isFutureOrUpcoming =>
      status.toLowerCase().contains('upcoming') ||
      status.toLowerCase().contains('not joined') ||
      status.toLowerCase().contains('not appointed');

  String get formattedNetDuration {
    if (firstIn == null || lastOut == null) {
      if (firstIn != null && lastOut == null) return 'In Progress';
      return '--';
    }
    final inDt = parseTime(firstInFormatted ?? firstIn!);
    final outDt = parseTime(lastOutFormatted ?? lastOut!);
    if (inDt == null || outDt == null) return '--';

    var diff = outDt.difference(inDt);
    if (diff.isNegative) {
      diff += const Duration(hours: 24);
    }
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  static DateTime? parseTime(String timeStr) {
    try {
      final s = timeStr.trim();
      final dateToday = DateTime.now();

      // Check ISO string
      if (s.contains('T') || (s.length >= 10 && s.contains('-'))) {
        final parsed = DateTime.tryParse(s);
        if (parsed != null) return parsed;
      }

      // Check 12-hour format with optional seconds: e.g. 09:15 AM or 09:15:30 AM
      final match12 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$', caseSensitive: false).firstMatch(s);
      if (match12 != null) {
        var hour = int.parse(match12.group(1)!);
        final min = int.parse(match12.group(2)!);
        final sec = match12.group(3) != null ? int.parse(match12.group(3)!) : 0;
        final period = match12.group(4)!.toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return DateTime(dateToday.year, dateToday.month, dateToday.day, hour, min, sec);
      }

      // Check 24-hour format: e.g. 14:30 or 14:30:15
      final parts = s.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final min = int.parse(parts[1].trim());
        final sec = parts.length >= 3 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
        return DateTime(dateToday.year, dateToday.month, dateToday.day, hour, min, sec);
      }
    } catch (_) {}
    return null;
  }
}

class AttendanceHistoryResponse {
  const AttendanceHistoryResponse({
    required this.periodLabel,
    required this.summary,
    required this.records,
  });

  final String periodLabel;
  final AttendanceSummary summary;
  final List<AttendanceRecord> records;
}

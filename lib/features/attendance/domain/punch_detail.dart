class ShiftOverviewMetrics {
  const ShiftOverviewMetrics({
    required this.totalLogged,
    required this.productive,
    required this.breakDuration,
  });

  final String totalLogged;
  final String productive;
  final String breakDuration;
}

class LateArrivalAlert {
  const LateArrivalAlert({
    required this.isLate,
    required this.lateMinutes,
    required this.graceWindowMinutes,
    required this.message,
  });

  final bool isLate;
  final int lateMinutes;
  final int graceWindowMinutes;
  final String message;
}

class ShiftOverview {
  const ShiftOverview({
    required this.date,
    required this.dayName,
    required this.formattedDate,
    required this.status,
    required this.shiftName,
    required this.shiftTiming,
    required this.lateArrivalAlert,
    required this.metrics,
  });

  final String date;
  final String dayName;
  final String formattedDate;
  final String status;
  final String shiftName;
  final String shiftTiming;
  final LateArrivalAlert? lateArrivalAlert;
  final ShiftOverviewMetrics metrics;
}

class PunchTouchpoint {
  const PunchTouchpoint({
    required this.number,
    required this.time,
    required this.statusTag,
    required this.title,
    required this.location,
    required this.deviceLabel,
    this.matchPercentage,
    this.similarityScore,
    this.deviceSource = 'mobile',
    this.eventUid,
    this.verificationCode,
    this.latitude,
    this.longitude,
    this.snapshotUrl,
    this.timestamp,
  });

  final int number;
  final String time;
  final String statusTag;
  final String title;
  final String location;
  final String deviceLabel;
  final double? matchPercentage;
  final double? similarityScore;
  final String deviceSource;
  final String? eventUid;
  final String? verificationCode;
  final double? latitude;
  final double? longitude;
  final String? snapshotUrl;
  final DateTime? timestamp;

  String get displayVerificationCode {
    if (verificationCode != null && verificationCode!.trim().isNotEmpty) {
      return verificationCode!.trim().toUpperCase();
    }
    if (eventUid != null && eventUid!.replaceAll('-', '').length >= 8) {
      return eventUid!.replaceAll('-', '').substring(0, 8).toUpperCase();
    }
    return '';
  }

  PunchTouchpoint copyWith({
    int? number,
    String? time,
    String? statusTag,
    String? title,
    String? location,
    String? deviceLabel,
    double? matchPercentage,
    double? similarityScore,
    String? deviceSource,
    String? eventUid,
    String? verificationCode,
    double? latitude,
    double? longitude,
    String? snapshotUrl,
    DateTime? timestamp,
  }) {
    return PunchTouchpoint(
      number: number ?? this.number,
      time: time ?? this.time,
      statusTag: statusTag ?? this.statusTag,
      title: title ?? this.title,
      location: location ?? this.location,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      similarityScore: similarityScore ?? this.similarityScore,
      deviceSource: deviceSource ?? this.deviceSource,
      eventUid: eventUid ?? this.eventUid,
      verificationCode: verificationCode ?? this.verificationCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class GeofenceAudit {
  const GeofenceAudit({
    required this.status,
    required this.perimeterDetails,
    required this.hardwareDisplay,
    required this.networkGateway,
    required this.ipStamp,
  });

  final String status;
  final String perimeterDetails;
  final String hardwareDisplay;
  final String networkGateway;
  final String ipStamp;
}

class ManagerReview {
  const ManagerReview({
    required this.statusLabel,
    required this.approverName,
    required this.approverTitle,
    required this.note,
  });

  final String statusLabel;
  final String approverName;
  final String approverTitle;
  final String note;
}

class PunchDetailData {
  const PunchDetailData({
    required this.shiftOverview,
    required this.touchpoints,
    required this.geofenceAudit,
    required this.managerReview,
  });

  final ShiftOverview shiftOverview;
  final List<PunchTouchpoint> touchpoints;
  final GeofenceAudit geofenceAudit;
  final ManagerReview managerReview;
}

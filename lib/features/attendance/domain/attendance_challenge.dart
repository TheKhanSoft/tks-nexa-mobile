class AttendanceChallenge {
  const AttendanceChallenge({
    required this.id,
    required this.nonce,
    required this.serverTimestamp,
    required this.expiresAt,
    required this.policy,
    this.location,
  });

  final String id;
  final String nonce;
  final DateTime serverTimestamp;
  final DateTime expiresAt;
  final AttendanceChallengePolicy policy;
  final AttendanceChallengeLocation? location;

  bool isExpiredAt(DateTime value) => !expiresAt.isAfter(value.toUtc());
}

class AttendanceChallengePolicy {
  const AttendanceChallengePolicy({
    required this.polygonGeofenceEnabled,
    required this.requireAppIntegrity,
    required this.cameraVerificationEnabled,
  });

  final bool polygonGeofenceEnabled;
  final bool requireAppIntegrity;
  final bool cameraVerificationEnabled;
}

class AttendanceChallengeLocation {
  const AttendanceChallengeLocation({
    required this.id,
    required this.name,
    required this.minimumAccuracyM,
    required this.polygon,
  });

  final String id;
  final String name;
  final double minimumAccuracyM;
  final List<AttendanceChallengePoint> polygon;
}

class AttendanceChallengePoint {
  const AttendanceChallengePoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

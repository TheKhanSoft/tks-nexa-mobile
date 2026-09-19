class LocationEvidence {
  const LocationEvidence({
    required this.latitude,
    required this.longitude,
    required this.horizontalAccuracyM,
    required this.capturedAt,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double horizontalAccuracyM;
  final DateTime capturedAt;
  final bool isMocked;

  bool isFreshAt(DateTime now, {required Duration maximumAge}) {
    final age = now.toUtc().difference(capturedAt.toUtc());
    return !age.isNegative && age <= maximumAge;
  }

  bool meetsAccuracy(double maximumAccuracyM) =>
      horizontalAccuracyM > 0 && horizontalAccuracyM <= maximumAccuracyM;

  Map<String, Object> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'horizontal_accuracy': horizontalAccuracyM,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }
}

class LocationEvidence {
  const LocationEvidence({
    required this.latitude,
    required this.longitude,
    required this.horizontalAccuracyM,
    required this.capturedAt,
    this.isMocked = false,
    this.locationName,
    this.wifiBssid,
    this.wifiSsid,
    this.wifiGatewayIp,
  });

  final double latitude;
  final double longitude;
  final double horizontalAccuracyM;
  final DateTime capturedAt;
  final bool isMocked;
  final String? locationName;
  final String? wifiBssid;
  final String? wifiSsid;
  final String? wifiGatewayIp;

  bool isFreshAt(DateTime now, {required Duration maximumAge}) {
    final age = now.toUtc().difference(capturedAt.toUtc());
    return !age.isNegative && age <= maximumAge;
  }

  bool meetsAccuracy(double maximumAccuracyM) =>
      horizontalAccuracyM > 0 && horizontalAccuracyM <= maximumAccuracyM;

  LocationEvidence copyWith({
    double? latitude,
    double? longitude,
    double? horizontalAccuracyM,
    DateTime? capturedAt,
    bool? isMocked,
    String? locationName,
    String? wifiBssid,
    String? wifiSsid,
    String? wifiGatewayIp,
  }) {
    return LocationEvidence(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      horizontalAccuracyM: horizontalAccuracyM ?? this.horizontalAccuracyM,
      capturedAt: capturedAt ?? this.capturedAt,
      isMocked: isMocked ?? this.isMocked,
      locationName: locationName ?? this.locationName,
      wifiBssid: wifiBssid ?? this.wifiBssid,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiGatewayIp: wifiGatewayIp ?? this.wifiGatewayIp,
    );
  }

  Map<String, Object> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'horizontal_accuracy': horizontalAccuracyM,
      if (locationName != null && locationName!.isNotEmpty)
        'location_name': locationName!,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'is_mocked': isMocked,
      if (wifiBssid != null && wifiBssid!.isNotEmpty)
        'wifi_bssid': wifiBssid!,
      if (wifiSsid != null && wifiSsid!.isNotEmpty)
        'wifi_ssid': wifiSsid!,
      if (wifiGatewayIp != null && wifiGatewayIp!.isNotEmpty)
        'wifi_gateway_ip': wifiGatewayIp!,
    };
  }
}

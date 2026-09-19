class AttendancePolicy {
  const AttendancePolicy({
    required this.mobileAttendanceEnabled,
    required this.requireLocation,
    required this.requireIntegrity,
    required this.requireRegisteredDevice,
    required this.requireFace,
    required this.requireLiveness,
    required this.polygonGeofenceEnabled,
    required this.cameraVerificationEnabled,
    required this.bleProximityEnabled,
    required this.nfcProximityEnabled,
    required this.uwbProximityEnabled,
    required this.wifiRttProximityEnabled,
    this.maximumLocationAccuracyM,
  });

  final bool mobileAttendanceEnabled;
  final bool requireLocation;
  final bool requireIntegrity;
  final bool requireRegisteredDevice;
  final bool requireFace;
  final bool requireLiveness;
  final bool polygonGeofenceEnabled;
  final bool cameraVerificationEnabled;
  final bool bleProximityEnabled;
  final bool nfcProximityEnabled;
  final bool uwbProximityEnabled;
  final bool wifiRttProximityEnabled;
  final double? maximumLocationAccuracyM;
}

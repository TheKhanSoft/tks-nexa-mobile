class DeviceSecurityEvidence {
  const DeviceSecurityEvidence({this.signature, this.integrityToken});

  final String? signature;
  final String? integrityToken;
}

class DeviceKeyDetails {
  const DeviceKeyDetails({
    required this.publicKey,
    required this.fingerprint,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
  });

  final String publicKey;
  final String fingerprint;
  final String platform;
  final String deviceModel;
  final String osVersion;
}

class DeviceSecurityStatus {
  const DeviceSecurityStatus({
    this.isRooted = false,
    this.isHooked = false,
    this.isTampered = false,
    this.details,
  });

  final bool isRooted;
  final bool isHooked;
  final bool isTampered;
  final String? details;
}

class WifiNetworkEvidence {
  const WifiNetworkEvidence({
    this.isWifiConnected = false,
    this.bssid,
    this.ssid,
    this.gatewayIp,
  });

  final bool isWifiConnected;
  final String? bssid;
  final String? ssid;
  final String? gatewayIp;
}

class DeviceTimeIntegrity {
  const DeviceTimeIntegrity({
    required this.elapsedRealtimeMs,
    required this.currentTimeMillis,
    required this.isAutoTimeEnabled,
    required this.isAutoTimeZoneEnabled,
  });

  final int elapsedRealtimeMs;
  final int currentTimeMillis;
  final bool isAutoTimeEnabled;
  final bool isAutoTimeZoneEnabled;
}

abstract interface class DeviceSecurityService {
  Future<DeviceKeyDetails?> getDeviceKey();

  Future<DeviceSecurityEvidence> createEvidence({
    required String canonicalPayload,
    required String integrityNonce,
    required bool requireIntegrity,
  });

  Future<DeviceSecurityStatus> checkDeviceSecurity();

  Future<WifiNetworkEvidence> getWifiDetails();

  Future<DeviceTimeIntegrity?> getDeviceTimeIntegrity();
}

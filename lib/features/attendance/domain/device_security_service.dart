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

abstract interface class DeviceSecurityService {
  Future<DeviceKeyDetails?> getDeviceKey();

  Future<DeviceSecurityEvidence> createEvidence({
    required String canonicalPayload,
    required String integrityNonce,
    required bool requireIntegrity,
  });
}

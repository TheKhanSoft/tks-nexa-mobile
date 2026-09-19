class ProximityEvidence {
  const ProximityEvidence({required this.protocol, required this.proof});

  final String protocol;
  final String proof;
}

abstract interface class ProximityService {
  Future<ProximityEvidence> collect({required String attendanceChallengeId});
}

abstract interface class BleProximityService implements ProximityService {}

abstract interface class NfcProximityService implements ProximityService {}

abstract interface class UwbProximityService implements ProximityService {}

abstract interface class WifiRttProximityService implements ProximityService {}

enum CameraCorroborationStatus {
  notRequired,
  alreadyCorroborated,
  challengeRequired,
  waitingForCamera,
  verified,
  expired,
  failed,
  unavailable;

  bool get isTerminal => switch (this) {
    notRequired || alreadyCorroborated || verified || expired || failed => true,
    challengeRequired || waitingForCamera || unavailable => false,
  };
}

class CameraCorroborationResult {
  const CameraCorroborationResult({
    required this.status,
    this.cameraChallengeId,
    this.expiresAt,
    this.message,
    this.remainingSeconds,
    this.matchedCamera,
  });

  final CameraCorroborationStatus status;
  final String? cameraChallengeId;
  final DateTime? expiresAt;
  final String? message;
  final int? remainingSeconds;
  final String? matchedCamera;
}

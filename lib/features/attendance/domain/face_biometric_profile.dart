class FaceBiometricProfile {
  FaceBiometricProfile({
    required this.employeeId,
    required List<double> embedding,
    required this.matchThreshold,
    required this.modelVersion,
    required this.livenessRequired,
    this.photoUrl,
  }) : embedding = List<double>.unmodifiable(embedding) {
    if (employeeId.trim().isEmpty ||
        (embedding.isNotEmpty &&
            embedding.length != 512 &&
            embedding.length != 192 &&
            embedding.length != 128) ||
        embedding.any((value) => !value.isFinite) ||
        !matchThreshold.isFinite ||
        matchThreshold <= 0 ||
        matchThreshold > 1 ||
        modelVersion.trim().isEmpty) {
      throw const FormatException('Invalid face biometric profile.');
    }
  }

  final String employeeId;
  final List<double> embedding;
  final double matchThreshold;
  final String modelVersion;
  final bool livenessRequired;
  final String? photoUrl;
}

class LocalFaceVerification {
  const LocalFaceVerification({
    required this.similarity,
    required this.threshold,
    required this.livenessPassed,
    required this.challenge,
    required this.modelVersion,
    this.liveVector,
    this.mirroredVector,
  });

  final double similarity;
  final double threshold;
  final bool livenessPassed;
  final String challenge;
  final String modelVersion;
  final List<double>? liveVector;
  final List<double>? mirroredVector;

  bool get matched => similarity >= threshold;
  bool get accepted => matched && livenessPassed;
}

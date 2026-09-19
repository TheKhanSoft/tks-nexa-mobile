class FaceBiometricProfile {
  FaceBiometricProfile({
    required this.employeeId,
    required List<double> embedding,
    required this.matchThreshold,
    required this.modelVersion,
    required this.livenessRequired,
  }) : embedding = List<double>.unmodifiable(embedding) {
    if (employeeId.trim().isEmpty ||
        embedding.length != 512 ||
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
}

class LocalFaceVerification {
  const LocalFaceVerification({
    required this.similarity,
    required this.threshold,
    required this.livenessPassed,
    required this.challenge,
    required this.modelVersion,
  });

  final double similarity;
  final double threshold;
  final bool livenessPassed;
  final String challenge;
  final String modelVersion;

  bool get matched => similarity >= threshold;
  bool get accepted => matched && livenessPassed;
}

import 'dart:math' as math;

class CosineFaceMatcher {
  const CosineFaceMatcher._();

  static double compare(List<double> live, List<double> enrolled) {
    if (live.isEmpty || live.length != enrolled.length) {
      throw const FormatException('Face embeddings are incompatible.');
    }
    var dot = 0.0;
    var liveMagnitude = 0.0;
    var enrolledMagnitude = 0.0;
    for (var index = 0; index < live.length; index++) {
      final a = live[index];
      final b = enrolled[index];
      if (!a.isFinite || !b.isFinite) throw const FormatException();
      dot += a * b;
      liveMagnitude += a * a;
      enrolledMagnitude += b * b;
    }
    final denominator = math.sqrt(liveMagnitude) * math.sqrt(enrolledMagnitude);
    if (denominator == 0 || !denominator.isFinite) {
      throw const FormatException('Face embedding has zero magnitude.');
    }
    return (dot / denominator).clamp(-1.0, 1.0);
  }

  /// Calibrates raw cosine dot product to human-comprehensible match percentage (0% - 100%).
  /// Matches the server's FaceBiometricService::calibrateCosineToMatchPercentage curve.
  static double calibrateToPercentage(double rawCosine) {
    final c = rawCosine.clamp(-1.0, 1.0);
    if (c <= 0.0) return 0.0;
    if (c <= 0.25) return c * 100.0;
    if (c <= 0.42) return 25.0 + (c - 0.25) * (30.0 / 0.17);
    if (c <= 0.48) return 55.0 + (c - 0.42) * (13.0 / 0.06);
    if (c <= 0.50) return 68.0 + (c - 0.48) * 100.0;
    if (c <= 0.70) return 70.0 + (c - 0.50) * 100.0;
    return (90.0 + (c - 0.70) * (10.0 / 0.30)).clamp(0.0, 100.0);
  }
}

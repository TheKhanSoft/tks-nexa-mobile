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
}

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/cosine_face_matcher.dart';

void main() {
  group('CosineFaceMatcher', () {
    test('returns 1.0 for identical vectors', () {
      final v = List<double>.generate(192, (i) => math.sin(i.toDouble()));
      final sim = CosineFaceMatcher.compare(v, v);
      expect(sim, closeTo(1.0, 0.0001));
    });

    test('returns low similarity for different / orthogonal vectors', () {
      final a = List<double>.filled(192, 0.0);
      final b = List<double>.filled(192, 0.0);
      for (var i = 0; i < 96; i++) {
        a[i] = 1.0;
      }
      for (var i = 96; i < 192; i++) {
        b[i] = 1.0;
      }
      final sim = CosineFaceMatcher.compare(a, b);
      expect(sim, closeTo(0.0, 0.0001));
    });

    test('returns high similarity for perturbed version of same vector', () {
      final a = List<double>.generate(192, (i) => math.sin(i.toDouble()));
      final b = List<double>.generate(192, (i) => math.sin(i.toDouble()) + 0.05 * math.cos(i.toDouble()));
      final sim = CosineFaceMatcher.compare(a, b);
      expect(sim, greaterThan(0.95));
    });
  });
}

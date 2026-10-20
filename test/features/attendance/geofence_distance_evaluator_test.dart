import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/geofence_distance_evaluator.dart';

void main() {
  group('GeofenceDistanceEvaluator Tests', () {
    // A square campus around (34.2000, 72.0400) ~100m wide
    const campusPolygon = [
      AttendanceChallengePoint(34.2005, 72.0395), // NW
      AttendanceChallengePoint(34.2005, 72.0405), // NE
      AttendanceChallengePoint(34.1995, 72.0405), // SE
      AttendanceChallengePoint(34.1995, 72.0395), // SW
    ];

    test('haversineMeters computes distance accurately', () {
      // Exactly 1 degree latitude distance is ~111,195 meters
      final dist = GeofenceDistanceEvaluator.haversineMeters(0.0, 0.0, 1.0, 0.0);
      expect(dist, greaterThan(111000));
      expect(dist, lessThan(112000));

      // Same point distance is 0
      final zeroDist = GeofenceDistanceEvaluator.haversineMeters(34.2, 72.0, 34.2, 72.0);
      expect(zeroDist, closeTo(0.0, 0.01));
    });

    test('isInsidePolygon identifies points inside and outside the perimeter', () {
      // Center point: (34.2000, 72.0400)
      expect(
        GeofenceDistanceEvaluator.isInsidePolygon(34.2000, 72.0400, campusPolygon),
        isTrue,
      );

      // Clearly outside (Far North)
      expect(
        GeofenceDistanceEvaluator.isInsidePolygon(34.2050, 72.0400, campusPolygon),
        isFalse,
      );

      // Clearly outside (Far East)
      expect(
        GeofenceDistanceEvaluator.isInsidePolygon(34.2000, 72.0500, campusPolygon),
        isFalse,
      );
    });

    test('distanceToPolygonMeters returns 0 for points inside perimeter', () {
      final insideDistance = GeofenceDistanceEvaluator.distanceToPolygonMeters(
        34.2000,
        72.0400,
        campusPolygon,
      );
      expect(insideDistance, equals(0.0));
    });

    test('distanceToPolygonMeters calculates positive distance for outside points', () {
      // 0.001 deg North of northern edge (34.2005) is 34.2015 (~111 meters away)
      final outsideDistance = GeofenceDistanceEvaluator.distanceToPolygonMeters(
        34.2015,
        72.0400,
        campusPolygon,
      );
      expect(outsideDistance, greaterThan(100));
      expect(outsideDistance, lessThan(125));
    });
  });
}

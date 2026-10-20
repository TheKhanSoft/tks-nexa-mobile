import 'dart:math' as math;
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';

class GeofenceDistanceEvaluator {
  const GeofenceDistanceEvaluator._();

  static const double earthRadiusMeters = 6371000.0;

  /// Computes distance in meters between two coordinates using the Haversine formula.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Determines if a point is inside a polygon using ray-casting.
  static bool isInsidePolygon(
    double lat,
    double lon,
    List<AttendanceChallengePoint> polygon,
  ) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final intersect = ((pi.longitude > lon) != (pj.longitude > lon)) &&
          (lat <
              (pj.latitude - pi.latitude) *
                      (lon - pi.longitude) /
                      (pj.longitude - pi.longitude) +
                  pi.latitude);

      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  /// Computes shortest distance in meters from point to polygon boundary.
  /// If point is inside polygon, returns 0.0.
  static double distanceToPolygonMeters(
    double lat,
    double lon,
    List<AttendanceChallengePoint> polygon,
  ) {
    if (polygon.isEmpty) return 0.0;
    if (isInsidePolygon(lat, lon, polygon)) return 0.0;

    double minDistance = double.infinity;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      // Distance to vertex
      final dVertex = haversineMeters(lat, lon, p1.latitude, p1.longitude);
      if (dVertex < minDistance) minDistance = dVertex;

      // Distance to edge segment projection
      final dEdge = _distanceToSegmentMeters(
        lat,
        lon,
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
      if (dEdge < minDistance) minDistance = dEdge;
    }

    return minDistance.isFinite ? minDistance : 0.0;
  }

  static double _distanceToSegmentMeters(
    double lat,
    double lon,
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final x = lon;
    final y = lat;
    final x1 = lon1;
    final y1 = lat1;
    final x2 = lon2;
    final y2 = lat2;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return haversineMeters(lat, lon, lat1, lon1);
    }

    final t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);

    final projLat = y1 + clampedT * dy;
    final projLon = x1 + clampedT * dx;

    return haversineMeters(lat, lon, projLat, projLon);
  }
}

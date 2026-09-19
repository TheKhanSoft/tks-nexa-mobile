import 'package:tks_nexa_attendance/features/attendance/domain/geo_point.dart';

class AttendanceLocation {
  const AttendanceLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.polygon,
    required this.minimumRequiredAccuracyM,
    required this.cameraVerificationAvailable,
    required this.enabled,
    this.fallbackCenter,
    this.fallbackRadiusM,
  });

  final String id;
  final String name;
  final String type;
  final List<GeoPoint> polygon;
  final GeoPoint? fallbackCenter;
  final double? fallbackRadiusM;
  final double minimumRequiredAccuracyM;
  final bool cameraVerificationAvailable;
  final bool enabled;

  bool get hasPolygon => polygon.length >= 3;
  bool get hasFallbackRadius =>
      fallbackCenter != null && fallbackRadiusM != null;
}

enum LocationEvaluationOutcome {
  inside,
  boundaryUncertain,
  outside;

  static LocationEvaluationOutcome fromWireValue(String value) {
    return switch (value.toUpperCase()) {
      'INSIDE' => inside,
      'BOUNDARY_UNCERTAIN' => boundaryUncertain,
      'OUTSIDE' => outside,
      _ => throw FormatException('Unknown location outcome: $value'),
    };
  }
}

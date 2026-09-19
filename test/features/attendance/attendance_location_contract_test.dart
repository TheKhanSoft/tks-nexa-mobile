import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/data/attendance_location_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_location.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

void main() {
  test('parses a polygon attendance location and camera availability', () {
    final location = AttendanceLocationDto.fromJson({
      'id': 51,
      'name': 'Main Campus',
      'type': 'campus',
      'polygon': [
        [34.1980, 72.0470],
        [34.1990, 72.0470],
        [34.1990, 72.0480],
        [34.1980, 72.0480],
      ],
      'fallback_latitude': 34.1985,
      'fallback_longitude': 72.0475,
      'fallback_radius_m': 100,
      'minimum_required_location_accuracy_m': 50,
      'camera_verification_available': true,
      'enabled': true,
    });

    expect(location.hasPolygon, isTrue);
    expect(location.polygon, hasLength(4));
    expect(location.hasFallbackRadius, isTrue);
    expect(location.cameraVerificationAvailable, isTrue);
  });

  test('understands the server boundary-uncertain outcome', () {
    expect(
      LocationEvaluationOutcome.fromWireValue('BOUNDARY_UNCERTAIN'),
      LocationEvaluationOutcome.boundaryUncertain,
    );
  });

  test('location submission contains evidence but no geofence conclusion', () {
    final json = LocationEvidence(
      latitude: 34.1981,
      longitude: 72.0478,
      horizontalAccuracyM: 8.4,
      capturedAt: DateTime.utc(2026, 9, 17, 8, 30),
    ).toJson();

    expect(json.keys, {
      'latitude',
      'longitude',
      'horizontal_accuracy',
      'captured_at',
    });
    expect(json, isNot(contains('inside_polygon')));
    expect(json, isNot(contains('inside_geofence')));
  });

  test('validates location freshness and accuracy before submission', () {
    final capturedAt = DateTime.utc(2026, 9, 18, 9, 30);
    final evidence = LocationEvidence(
      latitude: 34.1981,
      longitude: 72.0478,
      horizontalAccuracyM: 8.4,
      capturedAt: capturedAt,
    );

    expect(
      evidence.isFreshAt(
        capturedAt.add(const Duration(seconds: 15)),
        maximumAge: const Duration(seconds: 15),
      ),
      isTrue,
    );
    expect(
      evidence.isFreshAt(
        capturedAt.add(const Duration(seconds: 16)),
        maximumAge: const Duration(seconds: 15),
      ),
      isFalse,
    );
    expect(evidence.meetsAccuracy(50), isTrue);
    expect(evidence.meetsAccuracy(5), isFalse);
  });
}

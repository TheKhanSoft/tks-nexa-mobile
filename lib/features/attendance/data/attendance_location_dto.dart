import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_location.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/geo_point.dart';

class AttendanceLocationDto {
  const AttendanceLocationDto._();

  static AttendanceLocation fromJson(Map<String, dynamic> json) {
    try {
      final rawPolygon = json['polygon'];
      final polygon = rawPolygon == null
          ? const <GeoPoint>[]
          : (rawPolygon as List<dynamic>)
                .map((point) => _pointFromList(point as List<dynamic>))
                .toList(growable: false);
      if (polygon.isNotEmpty && polygon.length < 3) {
        throw const FormatException();
      }

      final fallbackLatitude = _optionalDouble(json['fallback_latitude']);
      final fallbackLongitude = _optionalDouble(json['fallback_longitude']);
      if ((fallbackLatitude == null) != (fallbackLongitude == null)) {
        throw const FormatException();
      }
      final fallbackCenter = fallbackLatitude == null
          ? null
          : _validatedPoint(fallbackLatitude, fallbackLongitude!);
      final fallbackRadius = _optionalDouble(json['fallback_radius_m']);
      if (fallbackRadius != null &&
          (fallbackRadius <= 0 || fallbackCenter == null)) {
        throw const FormatException();
      }

      final accuracy = _requiredDouble(
        json['minimum_required_location_accuracy_m'],
      );
      if (accuracy <= 0) throw const FormatException();

      final id = json['id']?.toString();
      final name = json['name'];
      final type = json['type'];
      final cameraAvailable = json['camera_verification_available'];
      final enabled = json['enabled'];
      if (id == null ||
          id.isEmpty ||
          name is! String ||
          name.trim().isEmpty ||
          type is! String ||
          type.trim().isEmpty ||
          cameraAvailable is! bool ||
          enabled is! bool) {
        throw const FormatException();
      }

      return AttendanceLocation(
        id: id,
        name: name.trim(),
        type: type.trim(),
        polygon: polygon,
        fallbackCenter: fallbackCenter,
        fallbackRadiusM: fallbackRadius,
        minimumRequiredAccuracyM: accuracy,
        cameraVerificationAvailable: cameraAvailable,
        enabled: enabled,
      );
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'An attendance location could not be loaded.',
        diagnosticCode: 'ATTENDANCE_LOCATION_INVALID',
      );
    }
  }

  static GeoPoint _pointFromList(List<dynamic> point) {
    if (point.length != 2) throw const FormatException();
    return _validatedPoint(
      _requiredDouble(point[0]),
      _requiredDouble(point[1]),
    );
  }

  static GeoPoint _validatedPoint(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException();
    }
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  static double _requiredDouble(Object? value) {
    if (value is num) return value.toDouble();
    throw const FormatException();
  }

  static double? _optionalDouble(Object? value) {
    if (value == null) return null;
    return _requiredDouble(value);
  }
}

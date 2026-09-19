import 'package:geolocator/geolocator.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_capture_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

class GeolocatorLocationCaptureService implements LocationCaptureService {
  const GeolocatorLocationCaptureService();

  @override
  Future<LocationEvidence> captureFresh() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message: 'Turn on location services to continue.',
        diagnosticCode: 'LOCATION_SERVICES_DISABLED',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AppFailure(
        code: FailureCode.unauthorized,
        message: 'Location permission is required for attendance.',
        diagnosticCode: 'LOCATION_PERMISSION_DENIED',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppFailure(
        code: FailureCode.unauthorized,
        message:
            'Location permission is blocked. Enable it from device settings.',
        diagnosticCode: 'LOCATION_PERMISSION_BLOCKED',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationEvidence(
        latitude: position.latitude,
        longitude: position.longitude,
        horizontalAccuracyM: position.accuracy,
        capturedAt: position.timestamp,
        isMocked: position.isMocked,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message: 'A fresh location could not be obtained. Please try again.',
        diagnosticCode: 'LOCATION_CAPTURE_FAILED',
      );
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/attendance/data/geolocator_location_capture_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_capture_service.dart';

final locationCaptureServiceProvider = Provider<LocationCaptureService>(
  (ref) => const GeolocatorLocationCaptureService(),
);

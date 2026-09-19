import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

abstract interface class LocationCaptureService {
  Future<LocationEvidence> captureFresh();
}

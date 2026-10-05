import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/application/mobile_attendance_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/biometric_scanning_verification_dialog.dart';

// 1x1 transparent PNG bytes for mock image
final _dummyImageBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeSubmissionController extends AttendanceSubmissionController {
  _FakeSubmissionController({this.resultToReturn, this.errorToThrow});

  final AttendanceMarkResult? resultToReturn;
  final Object? errorToThrow;

  @override
  Future<AttendanceMarkResult?> submit({
    required FaceCaptureEvidence capture,
    required LocationEvidence location,
  }) async {
    if (errorToThrow != null) {
      state = AsyncError(errorToThrow!, StackTrace.current);
      return null;
    }
    state = AsyncData(resultToReturn);
    return resultToReturn;
  }
}

void main() {
  final fakeCapture = FaceCaptureEvidence(
    bytes: _dummyImageBytes,
    contentType: 'image/jpeg',
    capturedAt: DateTime.now().toUtc(),
    livenessPassed: true,
    livenessChallenge: 'test',
  );

  final fakeLocation = LocationEvidence(
    latitude: 34.1981,
    longitude: 72.0478,
    horizontalAccuracyM: 8.4,
    capturedAt: DateTime.now().toUtc(),
  );

  testWidgets('renders scanning viewport and HUD elements', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceSubmissionProvider.overrideWith(
            () => _FakeSubmissionController(
              resultToReturn: const AttendanceMarkResult(
                message: 'Attendance recorded successfully.',
                attendanceId: '99',
                trustScore: 94,
                trustLevel: 'high',
                type: AttendanceType.checkIn,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BiometricScanningVerificationDialog(
              capture: fakeCapture,
              location: fakeLocation,
            ),
          ),
        ),
      ),
    );

    // Initial verifying state
    expect(find.text('BIOMETRIC SCANNING & MATCHING'), findsOneWidget);
    expect(find.text('EDGE-NET 512D'), findsOneWidget);
    expect(find.text('L2 UNIT |v|=1'), findsOneWidget);

    // Advance timer past the 1.6s visual delay
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Success state
    expect(find.text('VERIFICATION CONFIRMED'), findsOneWidget);
    expect(find.text('Identity Verified!'), findsOneWidget);
    expect(find.text('CHECK IN'), findsOneWidget);
    expect(find.text('Trust: 94% (high)'), findsOneWidget);
    expect(find.byKey(const Key('verification_done_button')), findsOneWidget);
  });

  testWidgets('displays error state on submission failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceSubmissionProvider.overrideWith(
            () => _FakeSubmissionController(
              errorToThrow: const AppFailure(
                code: FailureCode.invalidInput,
                message: 'Outside permitted geofence perimeter.',
                diagnosticCode: 'GEOFENCE_VIOLATION',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BiometricScanningVerificationDialog(
              capture: fakeCapture,
              location: fakeLocation,
            ),
          ),
        ),
      ),
    );

    // Advance timer past delay
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Failure state
    expect(find.text('VERIFICATION ATTENTION'), findsOneWidget);
    expect(find.text('Verification Incomplete'), findsOneWidget);
    expect(find.text('Outside permitted geofence perimeter.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

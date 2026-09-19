import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_hardware_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_capture_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/attendance_preparation_screen.dart';

class _FakeLocationCaptureService implements LocationCaptureService {
  @override
  Future<LocationEvidence> captureFresh() async => LocationEvidence(
    latitude: 34.1981,
    longitude: 72.0478,
    horizontalAccuracyM: 8.4,
    capturedAt: DateTime.now().toUtc(),
  );
}

void main() {
  testWidgets('captures and displays fresh location evidence', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationCaptureServiceProvider.overrideWithValue(
            _FakeLocationCaptureService(),
          ),
        ],
        child: const MaterialApp(home: AttendancePreparationScreen()),
      ),
    );

    await tester.scrollUntilVisible(find.text('Fresh location'), 250);
    expect(find.text('Fresh location'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Temporary face capture'), 250);
    expect(find.text('Temporary face capture'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Fresh location'), -250);

    await tester.tap(find.byKey(const Key('capture_location')));
    await tester.pumpAndSettle();

    expect(find.textContaining('34.19810, 72.04780'), findsOneWidget);
    expect(find.textContaining('±8 m'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('continue_attendance')),
      300,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue_attendance')))
          .onPressed,
      isNull,
    );
  });
}

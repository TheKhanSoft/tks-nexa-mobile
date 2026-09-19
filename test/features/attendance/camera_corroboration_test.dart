import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/features/attendance/application/camera_corroboration_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/camera_corroboration_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration_service.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/camera_verification_screen.dart';

class _WaitingCameraService implements CameraCorroborationService {
  _WaitingCameraService(this.result);

  final CameraCorroborationResult result;
  int calls = 0;

  @override
  Future<CameraCorroborationResult> getStatus({
    required String cameraChallengeId,
  }) async {
    calls++;
    return result;
  }
}

void main() {
  test('parses an invisible already-corroborated attendance response', () {
    final result = CameraCorroborationDto.fromAttendanceSubmissionJson({
      'status': 'accepted',
      'camera_corroboration': 'already_verified',
      'risk_score': 67,
      'camera_probability': 0.75,
    });

    expect(result.status, CameraCorroborationStatus.alreadyCorroborated);
    expect(result.cameraChallengeId, isNull);
  });

  test('parses a camera challenge without exposing risk information', () {
    final result = CameraCorroborationDto.fromAttendanceSubmissionJson({
      'status': 'camera_verification_required',
      'camera_challenge_id': 'camera-challenge-1',
      'expires_at': '2026-09-17T09:05:00Z',
      'message': 'Additional on-site verification is required.',
      'risk_score': 67,
      'camera_probability': 0.75,
    });

    expect(result.status, CameraCorroborationStatus.challengeRequired);
    expect(result.cameraChallengeId, 'camera-challenge-1');
    expect(result.toString(), isNot(contains('67')));
    expect(result.toString(), isNot(contains('0.75')));
  });

  testWidgets(
    'shows employee-safe camera instructions and verifies by polling',
    (tester) async {
      final verified = const CameraCorroborationResult(
        status: CameraCorroborationStatus.verified,
      );
      final service = _WaitingCameraService(verified);
      final expiry = DateTime.utc(2026, 9, 17, 9, 5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraCorroborationServiceProvider.overrideWithValue(service),
            cameraClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 9, 17, 9),
            ),
          ],
          child: MaterialApp(
            home: CameraVerificationScreen(
              initialResult: CameraCorroborationResult(
                status: CameraCorroborationStatus.challengeRequired,
                cameraChallengeId: 'camera-challenge-1',
                expiresAt: expiry,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(service.calls, 1);
      expect(find.text('Verification complete'), findsOneWidget);
      expect(find.textContaining('risk'), findsNothing);
      expect(find.textContaining('probability'), findsNothing);
    },
  );
}

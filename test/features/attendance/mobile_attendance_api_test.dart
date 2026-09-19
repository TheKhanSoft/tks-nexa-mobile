import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/features/attendance/data/cosine_face_matcher.dart';
import 'package:tks_nexa_attendance/features/attendance/data/mobile_attendance_api.dart';
import 'package:tks_nexa_attendance/features/attendance/data/secure_biometric_profile_store.dart';
import 'package:tks_nexa_attendance/features/attendance/data/secure_device_identity.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

import '../../support/fakes.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('loads and validates a protected 512-value face profile', () async {
    final dio = _MockDio();
    final api = MobileAttendanceApi(dio, 'access-token');
    when(
      () => dio.get<dynamic>(
        MobileAttendanceApi.faceProfilePath,
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: 'biometrics/face/profile'),
        statusCode: 200,
        data: {
          'status': 'success',
          'data': {
            'employee_id': 3,
            'enrolled': true,
            'embedding_vector': List<double>.filled(512, .05),
            'match_threshold': .79,
            'model_version': 'mobile_facenet_v1',
            'liveness_required': true,
          },
        },
      ),
    );

    final profile = await api.fetchFaceProfile();

    expect(profile.employeeId, '3');
    expect(profile.embedding, hasLength(512));
    expect(profile.matchThreshold, .79);
    final options =
        verify(
              () => dio.get<dynamic>(
                MobileAttendanceApi.faceProfilePath,
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as Options;
    expect(options.headers?['Authorization'], 'Bearer access-token');
  });

  test('submits only compact verified attendance evidence', () async {
    final dio = _MockDio();
    final api = MobileAttendanceApi(dio, 'access-token');
    when(
      () => dio.post<dynamic>(
        MobileAttendanceApi.markAttendancePath,
        options: any(named: 'options'),
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: 'attendance/mark'),
        statusCode: 200,
        data: {
          'status': 'success',
          'message': 'Checked in successfully.',
          'data': {
            'attendance_id': 44,
            'attendance_type': 'check_in',
            'recorded_at': '2026-09-19T08:01:02+05:00',
          },
        },
      ),
    );
    final request = AttendanceMarkRequest(
      type: AttendanceType.checkIn,
      verification: const LocalFaceVerification(
        similarity: .91,
        threshold: .78,
        livenessPassed: true,
        challenge: 'smile',
        modelVersion: 'mobile_facenet_v1',
      ),
      location: LocationEvidence(
        latitude: 34.1989,
        longitude: 72.0404,
        horizontalAccuracyM: 7,
        capturedAt: DateTime.utc(2026, 9, 19, 3, 1),
      ),
      deviceId: '0b851ad5-3f67-4b18-8ec5-e72ec6028354',
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        1726661100000,
        isUtc: true,
      ),
    );

    final result = await api.markAttendance(request);

    expect(result.attendanceId, '44');
    final captured =
        verify(
              () => dio.post<dynamic>(
                MobileAttendanceApi.markAttendancePath,
                options: any(named: 'options'),
                data: captureAny<dynamic>(named: 'data'),
              ),
            ).captured.single
            as Map<String, Object>;
    expect(captured['verified_method'], 'face_biometric');
    expect(captured['confidence_score'], .91);
    expect(captured['liveness_passed'], isTrue);
    expect(captured['latitude'], 34.1989);
    expect(captured, isNot(contains('embedding')));
    expect(captured, isNot(contains('image')));
  });

  test('securely stores the profile and stable tenant device id', () async {
    final storage = InMemorySecureStorage();
    final store = SecureBiometricProfileStore(storage, 'AWKUM');
    final profile = FaceBiometricProfile(
      employeeId: '3',
      embedding: List<double>.filled(512, .05),
      matchThreshold: .78,
      modelVersion: 'mobile_facenet_v1',
      livenessRequired: true,
    );

    await store.save(profile);
    final restored = await store.read();
    final identity = SecureDeviceIdentity(storage, 'AWKUM');
    final firstId = await identity.getOrCreate();
    final secondId = await identity.getOrCreate();

    expect(restored?.embedding, profile.embedding);
    expect(firstId, secondId);
    expect(storage.values.keys, everyElement(startsWith('tenant:awkum:')));
  });

  test(
    'cosine matcher accepts identical vectors and rejects orthogonal ones',
    () {
      final first = List<double>.filled(512, 0)..[0] = 1;
      final same = List<double>.from(first);
      final other = List<double>.filled(512, 0)..[1] = 1;

      expect(CosineFaceMatcher.compare(first, same), closeTo(1, 1e-10));
      expect(CosineFaceMatcher.compare(first, other), closeTo(0, 1e-10));
    },
  );
}

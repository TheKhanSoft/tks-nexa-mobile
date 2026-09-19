import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/features/account/data/employee_account_api.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('loads the authenticated employee profile', () async {
    final dio = _MockDio();
    final api = EmployeeAccountApi(dio, 'access-token');
    when(
      () => dio.get<dynamic>('profile', options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: 'profile'),
        statusCode: 200,
        data: {
          'status': 'success',
          'data': {
            'user': {
              'name': 'Ayesha Malik',
              'email': 'ayesha@example.test',
              'username': 'EMP-1042',
              'must_change_password': false,
            },
            'employee': {
              'full_name': 'Dr. Ayesha Malik',
              'father_name': 'Muhammad Malik',
              'cnic': '35202-1234567-1',
              'employee_code': 'EMP-1042',
              'designation': 'Chief Cardiologist',
              'office': 'Ward A',
              'campus': 'City Campus',
              'mobile_number': '03001234567',
              'gender': 'Female',
              'date_of_birth': '1988-01-02',
              'address': 'House 1',
              'city': 'Mardan',
              'province': 'Khyber Pakhtunkhwa',
              'postal_code': '23000',
              'is_active': true,
              'face_enrolled': true,
              'department': 'Cardiology',
              'designation_detail': {'grade': 'BPS-18'},
              'reporting_to': {'full_name': 'Medical Director'},
            },
            'attendance_permissions': {
              'can_mark_attendance': true,
              'reasons': <String>[],
            },
            'assigned_shift': {
              'name': 'Morning Shift',
              'code': 'morning',
              'start_time': '08:00:00',
              'end_time': '16:00:00',
              'grace_period_minutes': 15,
              'is_overnight': false,
            },
            'security': {
              'institutional_camera_available': true,
              'location_name': 'City Campus',
              'device': {
                'device_id': 'phone-1',
                'name': 'Pixel 9 Pro',
                'key_fingerprint': 'aabbccdd',
                'enrolled_at': '2026-09-19T08:00:00+05:00',
              },
              'trust_30_days': {
                'total_scans': 14,
                'average_score': 96.5,
                'high_trust_count': 13,
                'corroborated_count': 4,
              },
            },
          },
        },
      ),
    );

    final profile = await api.fetchProfile();

    expect(profile.name, 'Dr. Ayesha Malik');
    expect(profile.fatherName, 'Muhammad Malik');
    expect(profile.cnic, '35202-1234567-1');
    expect(profile.designation, 'Chief Cardiologist');
    expect(profile.department, 'Cardiology');
    expect(profile.designationGrade, 'BPS-18');
    expect(profile.canMarkAttendance, isTrue);
    expect(profile.assignedShift?.name, 'Morning Shift');
    expect(profile.security.institutionalCameraAvailable, isTrue);
    expect(profile.security.deviceName, 'Pixel 9 Pro');
    expect(profile.security.averageTrustScore, 96.5);
    expect(profile.security.corroboratedCount, 4);
    final options =
        verify(
              () => dio.get<dynamic>(
                'profile',
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as Options;
    expect(options.headers?['Authorization'], 'Bearer access-token');
  });

  test('changes password without sending a user id', () async {
    final dio = _MockDio();
    final api = EmployeeAccountApi(dio, 'access-token');
    when(
      () => dio.post<dynamic>(
        'auth/change-password',
        options: any(named: 'options'),
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: 'auth/change-password'),
        statusCode: 200,
        data: {'status': 'success'},
      ),
    );

    await api.changePassword(
      currentPassword: 'old-password',
      newPassword: 'new-password',
    );

    verify(
      () => dio.post<dynamic>(
        'auth/change-password',
        options: any(named: 'options'),
        data: {
          'current_password': 'old-password',
          'password': 'new-password',
          'password_confirmation': 'new-password',
        },
      ),
    ).called(1);
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/features/requests/application/requests_providers.dart';
import 'package:tks_nexa_attendance/features/requests/data/requests_api.dart';
import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/regularization_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/team_approval_item.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('TeamApprovalItem Domain Model Tests', () {
    test('TeamApprovalItem.fromLeave maps fields correctly', () {
      final leave = LeaveRequest(
        id: 42,
        publicId: 'LEAVE-42',
        reference: 'REF-42',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime(2026, 10, 25),
        endDate: DateTime(2026, 10, 27),
        formattedDates: '25 Oct 2026 – 27 Oct 2026',
        daysCount: 3,
        status: 'pending',
        reason: 'Family event attendance',
        createdAt: DateTime(2026, 10, 20),
        employeeName: 'Bilal Khan',
        employeeCode: 'EMP-2041',
        employeeDesignation: 'Assistant Professor',
        employeePhotoUrl: 'https://cdn.example.com/bilal.jpg',
      );

      final item = TeamApprovalItem.fromLeave(leave);

      expect(item.id, 42);
      expect(item.category, ApprovalCategory.leave);
      expect(item.categoryLabel, 'Leave');
      expect(item.title, 'Annual Leave');
      expect(item.subtitle, '3 days (25 Oct 2026 – 27 Oct 2026)');
      expect(item.dateDisplay, '25 Oct 2026 – 27 Oct 2026');
      expect(item.reason, 'Family event attendance');
      expect(item.employeeName, 'Bilal Khan');
      expect(item.employeeCode, 'EMP-2041');
      expect(item.employeeDesignation, 'Assistant Professor');
      expect(item.employeePhotoUrl, 'https://cdn.example.com/bilal.jpg');
      expect(item.daysCount, 3);
      expect(item.leaveRequest, leave);
      expect(item.dutyRequest, isNull);
      expect(item.regularizationRequest, isNull);
    });

    test('TeamApprovalItem.fromDuty maps fields correctly', () {
      final duty = OfficialDutyRequest(
        id: 88,
        publicId: 'DUTY-88',
        reference: 'REF-DUTY-88',
        dutyType: 'conference',
        dutyTypeLabel: 'Conference Duty',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 2),
        formattedDates: '01 Nov 2026 – 02 Nov 2026',
        daysCount: 2,
        location: 'Islamabad',
        hostOfficeName: 'Higher Education Commission',
        purpose: 'Keynote presentation on AI architectures',
        isRetrospective: false,
        hasDocument: true,
        status: 'pending',
        createdAt: DateTime(2026, 10, 20),
        employeeName: 'Dr. Sana Tariq',
        employeeCode: 'EMP-1105',
        employeeDesignation: 'Associate Dean',
      );

      final item = TeamApprovalItem.fromDuty(duty);

      expect(item.id, 88);
      expect(item.category, ApprovalCategory.officialDuty);
      expect(item.categoryLabel, 'Official Duty');
      expect(item.title, 'Conference Duty');
      expect(item.subtitle, 'Higher Education Commission • 2 days');
      expect(item.dateDisplay, '01 Nov 2026 – 02 Nov 2026');
      expect(item.reason, 'Keynote presentation on AI architectures');
      expect(item.employeeName, 'Dr. Sana Tariq');
      expect(item.employeeCode, 'EMP-1105');
      expect(item.employeeDesignation, 'Associate Dean');
      expect(item.daysCount, 2);
      expect(item.dutyRequest, duty);
      expect(item.leaveRequest, isNull);
    });

    test('TeamApprovalItem.fromRegularization maps fields correctly', () {
      final reg = RegularizationRequest(
        id: 104,
        publicId: 'REG-104',
        reference: 'REF-REG-104',
        date: DateTime(2026, 10, 19),
        formattedDate: '19 Oct 2026',
        punchType: 'check_in',
        punchTypeLabel: 'Check In',
        requestedPunchTime: '08:32 AM',
        formattedTime: '08:32 AM',
        reason: 'device_glitch',
        reasonLabel: 'Camera hardware malfunction',
        employeeRemarks: 'Camera failed on older handset',
        status: 'pending',
        statusLabel: 'Pending',
        createdAt: DateTime(2026, 10, 19, 9, 0),
        employeeName: 'Usman Ali',
        employeeCode: 'EMP-3002',
        employeeDesignation: 'IT Technician',
      );

      final item = TeamApprovalItem.fromRegularization(reg);

      expect(item.id, 104);
      expect(item.category, ApprovalCategory.regularization);
      expect(item.categoryLabel, 'Regularization');
      expect(item.title, 'Check In Regularization');
      expect(item.subtitle, 'Date: 19 Oct 2026 • Time: 08:32 AM');
      expect(item.reason, 'Camera hardware malfunction: Camera failed on older handset');
      expect(item.employeeName, 'Usman Ali');
      expect(item.employeeCode, 'EMP-3002');
      expect(item.regularizationRequest, reg);
    });

    test('RequestsOverview computes totalPendingApprovals correctly', () {
      const overview = RequestsOverview(
        pendingLeaveRequests: 2,
        pendingDutyRequests: 1,
        pendingRegularizationRequests: 3,
        pendingLeaveApprovals: 4,
        pendingDutyApprovals: 2,
        pendingRegularizationApprovals: 1,
      );

      expect(overview.totalPendingApprovals, 7);
    });
  });

  group('RequestsApi Approvals Actions Tests', () {
    test('approveLeave posts approved_days_count and comments', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/leaves/42/approve',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/leaves/42/approve'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.approveLeave(42, comments: 'Approved with full days', approvedDaysCount: 3);

      verify(() => dio.post<dynamic>(
            'v1/leaves/42/approve',
            data: {
              'comments': 'Approved with full days',
              'approved_days_count': 3,
            },
            options: any(named: 'options'),
          )).called(1);
    });

    test('rejectLeave posts rejection reason and comments', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/leaves/42/reject',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/leaves/42/reject'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.rejectLeave(42, reason: 'Staff shortage on given date');

      verify(() => dio.post<dynamic>(
            'v1/leaves/42/reject',
            data: {
              'reason': 'Staff shortage on given date',
              'comments': 'Staff shortage on given date',
            },
            options: any(named: 'options'),
          )).called(1);
    });

    test('approveOfficialDuty posts remarks', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/official-duties/88/approve',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/official-duties/88/approve'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.approveOfficialDuty(88, remarks: 'Safe travels');

      verify(() => dio.post<dynamic>(
            'v1/official-duties/88/approve',
            data: {'remarks': 'Safe travels'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('rejectOfficialDuty posts reason and remarks', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/official-duties/88/reject',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/official-duties/88/reject'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.rejectOfficialDuty(88, reason: 'Budget not sanctioned');

      verify(() => dio.post<dynamic>(
            'v1/official-duties/88/reject',
            data: {
              'reason': 'Budget not sanctioned',
              'remarks': 'Budget not sanctioned',
            },
            options: any(named: 'options'),
          )).called(1);
    });

    test('approveRegularization posts remarks', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/regularizations/104/approve',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/regularizations/104/approve'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.approveRegularization(104, remarks: 'Verified on security log');

      verify(() => dio.post<dynamic>(
            'v1/regularizations/104/approve',
            data: {'remarks': 'Verified on security log'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('rejectRegularization posts reason and remarks', () async {
      final dio = _MockDio();
      final api = RequestsApi(dio, 'manager-token');

      when(() => dio.post<dynamic>(
            'v1/regularizations/104/reject',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/regularizations/104/reject'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      await api.rejectRegularization(104, reason: 'No corroborating CCTV log');

      verify(() => dio.post<dynamic>(
            'v1/regularizations/104/reject',
            data: {
              'reason': 'No corroborating CCTV log',
              'remarks': 'No corroborating CCTV log',
            },
            options: any(named: 'options'),
          )).called(1);
    });
  });

  group('ApprovalActionNotifier State Transitions', () {
    test('ApprovalActionNotifier executes approval with loading state', () async {
      final dio = _MockDio();
      when(() => dio.post<dynamic>(
            'v1/leaves/42/approve',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: 'v1/leaves/42/approve'),
            statusCode: 200,
            data: {'status': 'success'},
          ));

      final container = ProviderContainer(
        overrides: [
          requestsApiProvider.overrideWithValue(RequestsApi(dio, 'test-token')),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(approvalActionProvider.notifier);
      final item = TeamApprovalItem.fromLeave(
        LeaveRequest(
          id: 42,
          publicId: 'LEAVE-42',
          reference: 'REF-42',
          leaveTypeName: 'Sick Leave',
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 20),
          formattedDates: '20 Oct 2026',
          daysCount: 1,
          status: 'pending',
          reason: 'Fever',
          createdAt: DateTime(2026, 10, 20),
        ),
      );

      final future = notifier.approve(item, comments: 'Get well soon');
      expect(container.read(approvalActionProvider).isLoading, true);

      await future;
      expect(container.read(approvalActionProvider).hasValue, true);
      expect(container.read(approvalActionProvider).hasError, false);
    });
  });
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';

class RequestsApi {
  const RequestsApi(this._dio, this._accessToken);

  final Dio _dio;
  final String _accessToken;

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  Future<List<LeaveType>> fetchLeaveTypes({int? year}) async {
    try {
      final response = await _dio.get<dynamic>(
        'v1/leaves/types',
        queryParameters: {if (year != null) 'year': year},
        options: _authorized,
      );
      final root = _asMap(response.data);
      final list = root['data'] is List ? root['data'] as List : const [];
      return list.whereType<Map>().map((map) {
        final m = Map<String, dynamic>.from(map);
        final ent = m['entitlement'] is Map ? Map<String, dynamic>.from(m['entitlement']) : {};
        return LeaveType(
          id: _int(m['id']),
          name: _string(m['name']),
          code: _string(m['code']),
          description: _string(m['description']),
          isPaid: m['is_paid'] == true,
          defaultDaysAllowed: _int(m['default_days_allowed'], fallback: 10),
          requiresDocument: m['requires_document'] == true,
          year: _int(m['year'], fallback: 2026),
          entitlement: LeaveEntitlement(
            allocated: _double(ent['allocated']),
            used: _double(ent['used']),
            pending: _double(ent['pending']),
            remaining: _double(ent['remaining']),
          ),
        );
      }).toList(growable: false);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load leave types.');
    }
  }

  Future<List<LeaveRequest>> fetchLeaveRequests({String? status, int? year}) async {
    try {
      final response = await _dio.get<dynamic>(
        'v1/leaves',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (year != null) 'year': year,
        },
        options: _authorized,
      );
      final root = _asMap(response.data);
      final list = root['data'] is List ? root['data'] as List : const [];
      return list.whereType<Map>().map((map) {
        final m = Map<String, dynamic>.from(map);
        final lt = m['leave_type'] is Map ? Map<String, dynamic>.from(m['leave_type']) : {};
        final approvalsList = m['approvals'] is List ? m['approvals'] as List : const [];
        final approvals = approvalsList.whereType<Map>().map((a) {
          final am = Map<String, dynamic>.from(a);
          return ApprovalStep(
            id: _int(am['id']),
            approverName: _string(am['approver_name'], fallback: 'Manager'),
            action: _string(am['action'], fallback: 'Pending'),
            comments: _stringOpt(am['comments']),
            decidedAt: _dateTime(am['decided_at']),
          );
        }).toList(growable: false);

        return LeaveRequest(
          id: _int(m['id']),
          publicId: _string(m['public_id']),
          reference: _string(m['reference']),
          leaveTypeName: _string(lt['name'], fallback: 'Leave'),
          startDate: _date(m['start_date']),
          endDate: _date(m['end_date']),
          formattedDates: _string(m['formatted_dates'], fallback: '${m['start_date']} – ${m['end_date']}'),
          daysCount: _int(m['days_count'], fallback: 1),
          status: _string(m['status'], fallback: 'Pending'),
          reason: _string(m['reason']),
          createdAt: _dateTime(m['created_at']) ?? DateTime.now(),
          approvals: approvals,
        );
      }).toList(growable: false);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load leave requests.');
    }
  }

  Future<void> applyLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      await _dio.post<dynamic>(
        'v1/leaves/apply',
        data: {
          'leave_type_id': leaveTypeId,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        },
        options: _authorized,
      );
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Leave application could not be submitted.');
    }
  }

  Future<List<OfficialDutyTypeOption>> fetchOfficialDutyTypes() async {
    return const [
      OfficialDutyTypeOption(key: 'official_tour', label: 'Official Tour'),
      OfficialDutyTypeOption(key: 'training', label: 'Training'),
      OfficialDutyTypeOption(key: 'field_visit', label: 'Field Visit'),
      OfficialDutyTypeOption(key: 'temporary_duty', label: 'Temporary Duty'),
      OfficialDutyTypeOption(key: 'conference', label: 'Conference'),
      OfficialDutyTypeOption(key: 'deputation', label: 'Deputation'),
      OfficialDutyTypeOption(key: 'other', label: 'Other'),
    ];
  }

  Future<List<HostOffice>> fetchHostOffices() async {
    try {
      final response = await _dio.get<dynamic>(
        'v1/official-duties/offices',
        options: _authorized,
      );
      final root = _asMap(response.data);
      final list = root['data'] is List ? root['data'] as List : const [];
      return list.whereType<Map>().map((map) {
        final m = Map<String, dynamic>.from(map);
        return HostOffice(
          id: _int(m['id']),
          name: _string(m['name']),
          campusName: _stringOpt(m['campus_name']),
        );
      }).toList(growable: false);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load host offices.');
    }
  }

  Future<List<OfficialDutyRequest>> fetchOfficialDutyRequests({String? status, int? year}) async {
    try {
      final response = await _dio.get<dynamic>(
        'v1/official-duties',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (year != null) 'year': year,
        },
        options: _authorized,
      );
      final root = _asMap(response.data);
      final list = root['data'] is List ? root['data'] as List : const [];
      return list.whereType<Map>().map((map) {
        final m = Map<String, dynamic>.from(map);
        final ho = m['host_office'] is Map ? Map<String, dynamic>.from(m['host_office']) : {};
        return OfficialDutyRequest(
          id: _int(m['id']),
          publicId: _string(m['public_id']),
          reference: _string(m['reference']),
          dutyType: _string(m['duty_type']),
          dutyTypeLabel: _string(m['duty_type_label'], fallback: 'Official Duty'),
          startDate: _date(m['start_date']),
          endDate: _date(m['end_date']),
          formattedDates: _string(m['formatted_dates'], fallback: '${m['start_date']} – ${m['end_date']}'),
          daysCount: _int(m['days_count'], fallback: 1),
          location: _string(m['location']),
          hostOfficeName: _string(ho['name'], fallback: 'Main Office'),
          purpose: _string(m['purpose']),
          isRetrospective: m['is_retrospective'] == true,
          hasDocument: m['has_document'] == true,
          status: _string(m['status'], fallback: 'Pending'),
          createdAt: _dateTime(m['created_at']) ?? DateTime.now(),
          documentUrl: _stringOpt(m['document_url']),
          approverName: _stringOpt(m['approver_name']),
          referenceNumber: _stringOpt(m['reference_number']),
          remarks: _stringOpt(m['remarks']),
        );
      }).toList(growable: false);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load official duty requests.');
    }
  }

  Future<void> applyOfficialDuty({
    required String dutyType,
    required String startDate,
    required String endDate,
    required String location,
    required int hostOfficeId,
    required String purpose,
    String? referenceNumber,
    String? remarks,
    File? document,
  }) async {
    try {
      final formData = FormData.fromMap({
        'duty_type': dutyType,
        'start_date': startDate,
        'end_date': endDate,
        'location': location,
        'host_office_id': hostOfficeId,
        'purpose': purpose,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (document != null)
          'document': await MultipartFile.fromFile(
            document.path,
            filename: document.path.split(Platform.pathSeparator).last,
          ),
      });

      await _dio.post<dynamic>(
        'v1/official-duties/apply',
        data: formData,
        options: _authorized,
      );
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Official duty request could not be submitted.');
    }
  }

  Future<RequestsOverview> fetchRequestsOverview() async {
    try {
      final response = await _dio.get<dynamic>(
        'v1/requests/overview',
        options: _authorized,
      );
      final root = _asMap(response.data);
      final data = root['data'] is Map ? Map<String, dynamic>.from(root['data']) : root;
      return RequestsOverview(
        pendingLeaveRequests: _int(data['pending_leave_requests']),
        pendingDutyRequests: _int(data['pending_duty_requests']),
      );
    } on Object {
      return const RequestsOverview();
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const AppFailure(
      code: FailureCode.invalidResponse,
      message: 'The requests service returned an invalid response.',
      diagnosticCode: 'REQUESTS_RESPONSE_INVALID',
    );
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _double(Object? value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  static String? _stringOpt(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime _date(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim()) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _dateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static AppFailure _failureFor(DioException error, {required String fallback}) {
    final status = error.response?.statusCode;
    final response = error.response?.data;
    String? message;
    String? diagnostic;
    if (response is Map) {
      if (response['message'] is String) message = response['message'] as String;
      if (response['diagnostic'] is String) diagnostic = response['diagnostic'] as String;
    }
    return AppFailure(
      code: switch (status) {
        401 => FailureCode.unauthorized,
        403 || 422 => FailureCode.invalidInput,
        429 => FailureCode.rateLimited,
        _ => FailureCode.unavailable,
      },
      message: message ?? fallback,
      diagnosticCode: diagnostic ?? 'REQUESTS_API_ERROR',
    );
  }
}

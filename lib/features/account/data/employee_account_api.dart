import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';

class EmployeeAccountApi {
  const EmployeeAccountApi(this._dio, this._accessToken);

  final Dio _dio;
  final String _accessToken;

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  Future<EmployeeProfile> fetchProfile() async {
    try {
      final response = await _dio.get<dynamic>('profile', options: _authorized);
      final root = _asMap(response.data);
      final data = _asMap(root['data']);
      final user = _asMap(data['user']);
      final employee = _asMap(data['employee']);
      final designation = _asOptionalMap(employee['designation_detail']);
      final reportingTo = _asOptionalMap(employee['reporting_to']);
      final permissions = _asOptionalMap(data['attendance_permissions']);
      final shift = _asOptionalMap(data['assigned_shift']);
      final security = _asOptionalMap(data['security']);
      final device = _asOptionalMap(security?['device']);
      final trust = _asOptionalMap(security?['trust_30_days']);
      return EmployeeProfile(
        name: _string(employee['full_name'], fallback: user['name']),
        email: _string(user['email']),
        employeeCode: _string(employee['employee_code']),
        fatherName: _string(employee['father_name']),
        cnic: _string(employee['cnic']),
        designation: _string(employee['designation']),
        office: _string(employee['office']),
        campus: _string(employee['campus']),
        mobileNumber: _string(
          employee['mobile_number'],
          fallback: employee['contact_number'],
        ),
        gender: _string(employee['gender']),
        isActive: employee['is_active'] == true,
        faceEnrolled: employee['face_enrolled'] == true,
        photoUrl: employee['photo_url'] is String
            ? employee['photo_url'] as String
            : null,
        username: _string(user['username'], fallback: employee['username']),
        dateOfBirth: _string(employee['date_of_birth']),
        address: _string(employee['address']),
        city: _string(employee['city']),
        province: _string(employee['province']),
        postalCode: _string(employee['postal_code']),
        designationGrade: _string(designation?['grade']),
        department: _string(
          employee['department'],
          fallback: employee['office'],
        ),
        reportingTo: _string(reportingTo?['full_name']),
        mustChangePassword: user['must_change_password'] == true,
        canMarkAttendance: permissions?['can_mark_attendance'] == true,
        attendanceReasons: _stringList(permissions?['reasons']),
        assignedShift: shift == null
            ? null
            : EmployeeShiftProfile(
                name: _string(shift['name']),
                code: _string(shift['code']),
                startTime: _string(shift['start_time']),
                endTime: _string(shift['end_time']),
                gracePeriodMinutes: shift['grace_period_minutes'] is num
                    ? (shift['grace_period_minutes'] as num).toInt()
                    : 0,
                isOvernight: shift['is_overnight'] == true,
              ),
        security: EmployeeSecurityProfile(
          institutionalCameraAvailable:
              security?['institutional_camera_available'] == true,
          locationName: _string(security?['location_name']),
          deviceId: _string(device?['device_id']),
          deviceName: _string(device?['name']),
          keyFingerprint: _string(device?['key_fingerprint']),
          deviceEnrolledAt: _dateTime(device?['enrolled_at']),
          totalScans: _integer(trust?['total_scans']),
          averageTrustScore: _double(trust?['average_score']),
          highTrustCount: _integer(trust?['high_trust_count']),
          corroboratedCount: _integer(trust?['corroborated_count']),
        ),
      );
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load your profile.');
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The profile response was incomplete.',
        diagnosticCode: 'PROFILE_RESPONSE_INVALID',
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<dynamic>(
        'auth/change-password',
        options: _authorized,
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        },
      );
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to change your password.');
    }
  }

  Future<void> logout() async {
    await _dio.post<dynamic>('auth/logout', options: _authorized);
  }

  static AppFailure _failureFor(
    DioException error, {
    required String fallback,
  }) {
    final status = error.response?.statusCode;
    final response = error.response?.data;
    String? serverMessage;
    if (response is Map && response['message'] is String) {
      serverMessage = response['message'] as String;
    }
    return AppFailure(
      code: status == 401
          ? FailureCode.unauthorized
          : status == 422
          ? FailureCode.invalidInput
          : FailureCode.unavailable,
      message: serverMessage ?? fallback,
      diagnosticCode: status == 401
          ? 'SESSION_EXPIRED'
          : status == 422
          ? 'ACCOUNT_VALIDATION_FAILED'
          : 'ACCOUNT_UNAVAILABLE',
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }

  static Map<String, dynamic>? _asOptionalMap(Object? value) {
    if (value == null) return null;
    return _asMap(value);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().map((item) => item.trim()).toList();
  }

  static String _string(Object? value, {Object? fallback}) {
    final selected = value is String && value.trim().isNotEmpty
        ? value
        : fallback;
    return selected is String ? selected.trim() : '';
  }

  static int _integer(Object? value) => value is num ? value.toInt() : 0;

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _dateTime(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toLocal() : null;
  }
}

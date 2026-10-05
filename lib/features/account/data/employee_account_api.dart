import 'dart:typed_data';

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
      final data = root['data'] is Map ? _asMap(root['data']) : root;
      final user = _asOptionalMap(data['user']) ?? data;
      final employee = _asOptionalMap(data['employee']) ?? data;
      final designation = _asOptionalMap(employee['designation_detail']);
      final reportingTo = _asOptionalMap(employee['reporting_to']);
      final permissions = _asOptionalMap(data['attendance_permissions']);
      final shift = _asOptionalMap(data['assigned_shift']);
      final security = _asOptionalMap(data['security']);
      final device = _asOptionalMap(security?['device']);
      final trust = _asOptionalMap(security?['trust_30_days']);

      final employeeCode = _extractEmployeeId(employee, user, data);

      return EmployeeProfile(
        name: _string(employee['full_name'], fallback: user['name']),
        email: _string(user['email']),
        employeeCode: employeeCode,
        fatherName: _string(employee['father_name']),
        cnic: _string(employee['cnic']),
        designation: _string(employee['designation']),
        office: _string(employee['office']),
        campus: _string(employee['campus']),
        mobileNumber: _string(
          employee['mobile_number'],
          fallback: _string(employee['contact_number']),
        ),
        gender: _string(employee['gender']),
        isActive: employee['is_active'] == true,
        faceEnrolled: employee['face_enrolled'] == true,
        photoUrl: employee['photo_url'] is String
            ? employee['photo_url'] as String
            : null,
        username: _string(user['username'], fallback: _string(employee['username'])),
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
        mustChangePassword: user['must_change_password'] == true ||
            data['must_change_password'] == true ||
            employee['must_change_password'] == true,
        canMarkAttendance: permissions?['can_mark_attendance'] == true,
        attendanceReasons: _asStringList(permissions?['reasons']),
        assignedShift: shift == null
            ? null
            : EmployeeShiftProfile(
                name: _string(shift['name'], fallback: 'Standard Shift'),
                code: _string(shift['code']),
                startTime: _string(shift['start_time'], fallback: '08:00:00'),
                endTime: _string(shift['end_time'], fallback: '17:00:00'),
                gracePeriodMinutes: shift['grace_period_minutes'] is num
                    ? (shift['grace_period_minutes'] as num).toInt()
                    : 15,
                isOvernight: shift['is_overnight'] == true,
              ),
        security: EmployeeSecurityProfile(
          institutionalCameraAvailable:
              security?['institutional_camera_available'] == true,
          locationName: _string(security?['location_name']),
          deviceId: _string(device?['device_id']),
          deviceName: _string(device?['device_name'], fallback: _string(device?['name'])),
          keyFingerprint: _string(device?['key_fingerprint']),
          deviceEnrolledAt: _dateTime(device?['enrolled_at']),
          totalScans: trust?['total_scans'] is num
              ? (trust!['total_scans'] as num).toInt()
              : 0,
          averageTrustScore: _double(trust?['average_trust_score']) ??
              _double(trust?['average_score']),
          highTrustCount: trust?['high_trust_count'] is num
              ? (trust!['high_trust_count'] as num).toInt()
              : 0,
          corroboratedCount: trust?['corroborated_count'] is num
              ? (trust!['corroborated_count'] as num).toInt()
              : 0,
        ),
      );
    } on DioException catch (error) {
      throw switch (error.response?.statusCode) {
        401 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Your session expired. Please sign in again.',
          diagnosticCode: 'ACCOUNT_UNAUTHORIZED',
        ),
        403 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Access to this account details is restricted.',
          diagnosticCode: 'ACCOUNT_FORBIDDEN',
        ),
        _ => const AppFailure(
          code: FailureCode.unavailable,
          message: 'Employee details are temporarily unavailable.',
          diagnosticCode: 'ACCOUNT_UNAVAILABLE',
        ),
      };
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The account service returned invalid details.',
        diagnosticCode: 'ACCOUNT_RESPONSE_INVALID',
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
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        },
        options: _authorized,
      );
    } on DioException catch (error) {
      throw switch (error.response?.statusCode) {
        401 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Your current password is incorrect.',
          diagnosticCode: 'PASSWORD_CHANGE_REJECTED',
        ),
        422 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Check your password details and try again.',
          diagnosticCode: 'PASSWORD_CHANGE_VALIDATION_FAILED',
        ),
        _ => const AppFailure(
          code: FailureCode.unavailable,
          message: 'Password change is temporarily unavailable.',
          diagnosticCode: 'PASSWORD_CHANGE_UNAVAILABLE',
        ),
      };
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The password change service returned an invalid response.',
        diagnosticCode: 'PASSWORD_CHANGE_RESPONSE_INVALID',
      );
    }
  }

  Future<String> uploadProfilePhoto({
    Uint8List? photoBytes,
    String? photoBase64,
    List<double>? embedding,
    String fileName = 'face_photo.jpg',
  }) async {
    try {
      dynamic payload;
      if (photoBytes != null) {
        final map = <String, dynamic>{
          'photo': MultipartFile.fromBytes(photoBytes, filename: fileName),
        };
        if (embedding != null && embedding.isNotEmpty) {
          map['embedding'] = embedding;
          map['face_vector'] = embedding;
        }
        payload = FormData.fromMap(map);
      } else if (photoBase64 != null && photoBase64.isNotEmpty) {
        final map = <String, dynamic>{'photo_base64': photoBase64};
        if (embedding != null && embedding.isNotEmpty) {
          map['embedding'] = embedding;
          map['face_vector'] = embedding;
        }
        payload = map;
      } else {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'No photo provided for upload.',
          diagnosticCode: 'NO_PHOTO_PROVIDED',
        );
      }

      final response = await _dio.post<dynamic>(
        'profile/photo',
        data: payload,
        options: _authorized,
      );
      final root = _asMap(response.data);
      final resData = root['data'] is Map ? _asMap(root['data']) : root;
      return _string(resData['photo_url']);
    } on DioException catch (error) {
      throw switch (error.response?.statusCode) {
        401 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'Your session expired. Please sign in again.',
          diagnosticCode: 'PHOTO_UPLOAD_UNAUTHORIZED',
        ),
        422 => const AppFailure(
          code: FailureCode.invalidInput,
          message: 'The photo file is invalid. Please take a clear face photo.',
          diagnosticCode: 'PHOTO_UPLOAD_INVALID',
        ),
        _ => const AppFailure(
          code: FailureCode.unavailable,
          message: 'Failed to upload profile photo. Please try again.',
          diagnosticCode: 'PHOTO_UPLOAD_UNAVAILABLE',
        ),
      };
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The photo upload service returned an invalid response.',
        diagnosticCode: 'PHOTO_UPLOAD_RESPONSE_INVALID',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('auth/logout', options: _authorized);
    } on Object {
      // Local logout must proceed even if the network fails.
    }
  }

  static String _extractEmployeeId(
    Map<String, dynamic> employee,
    Map<String, dynamic> user,
    Map<String, dynamic> data,
  ) {
    for (final map in [employee, data, user]) {
      final code = map['employee_code'] ??
          map['code'] ??
          map['employee_id'] ??
          map['emp_code'] ??
          map['emp_id'];
      if (code != null && code.toString().trim().isNotEmpty) {
        return code.toString().trim();
      }
    }
    return '';
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const AppFailure(
      code: FailureCode.invalidResponse,
      message: 'The account service returned an invalid format.',
      diagnosticCode: 'ACCOUNT_FORMAT_INVALID',
    );
  }

  static Map<String, dynamic>? _asOptionalMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  static List<String> _asStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static DateTime? _dateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

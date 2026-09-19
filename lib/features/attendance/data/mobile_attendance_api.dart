import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_biometric_profile_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/data/attendance_challenge_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_mark.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_challenge.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';
import 'package:tks_nexa_attendance/features/attendance/data/camera_corroboration_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/mobile_attendance_service.dart';

class MobileAttendanceApi implements MobileAttendanceService {
  const MobileAttendanceApi(this._dio, this._accessToken);

  static const faceProfilePath = 'biometrics/face/profile';
  static const markAttendancePath = 'attendance/mark';
  static const challengePath = 'attendance/challenge';
  static const submitAttendancePath = 'attendance/submit';

  final Dio _dio;
  final String _accessToken;

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<FaceBiometricProfile> fetchFaceProfile() async {
    try {
      final response = await _dio.get<dynamic>(
        faceProfilePath,
        options: _authorized,
      );
      return FaceBiometricProfileDto.fromResponse(response.data);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Unable to load face enrollment.');
    }
  }

  @override
  Future<AttendanceChallenge> requestChallenge({
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        challengePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'X-Device-ID': deviceId,
          },
        ),
        data: const <String, Object>{},
      );
      return AttendanceChallengeDto.fromResponse(response.data);
    } on DioException catch (error) {
      throw _failureFor(
        error,
        fallback: 'A secure attendance challenge could not be created.',
      );
    }
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required DeviceKeyDetails key,
    required String appVersion,
  }) async {
    try {
      await _dio.post<dynamic>(
        'devices',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'X-Device-ID': deviceId,
          },
        ),
        data: {
          'device_id': deviceId,
          'public_key': key.publicKey,
          'platform': key.platform,
          'device_model': key.deviceModel,
          'app_version': appVersion,
          'os_version': key.osVersion,
        },
      );
    } on DioException catch (error) {
      throw _failureFor(
        error,
        fallback: 'This phone could not be registered securely.',
      );
    }
  }

  @override
  Future<AttendanceMarkResult> markAttendance(
    AttendanceMarkRequest request,
  ) async {
    if (!request.verification.accepted || request.location.isMocked) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Attendance evidence did not pass local safety checks.',
        diagnosticCode: 'ATTENDANCE_EVIDENCE_REJECTED',
      );
    }
    try {
      final response = await _dio.post<dynamic>(
        submitAttendancePath,
        options: _authorized,
        data: request.toJson(),
      );
      return _resultFromResponse(response.data, request.type);
    } on DioException catch (error) {
      throw _failureFor(error, fallback: 'Attendance could not be recorded.');
    }
  }

  static AttendanceMarkResult _resultFromResponse(
    Object? response,
    AttendanceType fallbackType,
  ) {
    try {
      final root = _map(response);
      final data = root['data'] is Map ? _map(root['data']) : root;
      final rawType = data['attendance_type'] ?? data['type'];
      final type = switch (rawType) {
        'check_in' => AttendanceType.checkIn,
        'check_out' => AttendanceType.checkOut,
        _ => fallbackType,
      };
      final rawRecordedAt =
          data['recorded_at'] ?? data['attendance_time'] ?? data['created_at'];
      return AttendanceMarkResult(
        message: root['message'] is String
            ? (root['message'] as String).trim()
            : 'Attendance recorded successfully.',
        attendanceId: (data['id'] ?? data['attendance_id'])?.toString(),
        recordedAt: rawRecordedAt is String
            ? DateTime.tryParse(rawRecordedAt)?.toLocal()
            : null,
        type: type,
        trustScore: _trustScore(data),
        trustLevel: _trustLevel(data),
        cameraCorroboration:
            CameraCorroborationDto.fromAttendanceSubmissionJson(root),
      );
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'Attendance was received but the confirmation was invalid.',
        diagnosticCode: 'ATTENDANCE_RESPONSE_INVALID',
      );
    }
  }

  static int? _trustScore(Map<String, dynamic> data) {
    final direct = data['trust_score'];
    if (direct is num) return direct.round();
    final trust = data['trust'];
    if (trust is Map && trust['score'] is num) {
      return (trust['score'] as num).round();
    }
    return null;
  }

  static String? _trustLevel(Map<String, dynamic> data) {
    final direct = data['trust_level'];
    if (direct is String) return direct;
    final trust = data['trust'];
    if (trust is Map && trust['level'] is String) {
      return trust['level'] as String;
    }
    return null;
  }

  static AppFailure _failureFor(
    DioException error, {
    required String fallback,
  }) {
    final status = error.response?.statusCode;
    final response = error.response?.data;
    String? serverMessage;
    String? diagnostic;
    if (response is Map) {
      if (response['message'] is String) {
        serverMessage = response['message'] as String;
      }
      if (response['diagnostic'] is String) {
        diagnostic = response['diagnostic'] as String;
      }
    }
    return AppFailure(
      code: switch (status) {
        401 => FailureCode.unauthorized,
        403 || 422 => FailureCode.invalidInput,
        409 => FailureCode.invalidInput,
        429 => FailureCode.rateLimited,
        _ => FailureCode.unavailable,
      },
      message: serverMessage ?? fallback,
      diagnosticCode: diagnostic ?? 'ATTENDANCE_API_UNAVAILABLE',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}

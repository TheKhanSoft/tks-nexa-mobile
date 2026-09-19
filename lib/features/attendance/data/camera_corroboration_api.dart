import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/data/camera_corroboration_dto.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration_service.dart';

class CameraCorroborationApi implements CameraCorroborationService {
  CameraCorroborationApi(this._dio, this._accessToken);

  final Dio _dio;
  final String _accessToken;

  @override
  Future<CameraCorroborationResult> getStatus({
    required String cameraChallengeId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'attendance/camera-verification/${Uri.encodeComponent(cameraChallengeId)}',
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );
      final data = response.data;
      if (data is! Map) throw const FormatException();
      return CameraCorroborationDto.fromStatusJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException {
      throw const AppFailure(
        code: FailureCode.unavailable,
        message: 'Camera verification status is temporarily unavailable.',
        diagnosticCode: 'CAMERA_STATUS_UNAVAILABLE',
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'Camera verification status could not be loaded.',
        diagnosticCode: 'CAMERA_STATUS_INVALID',
      );
    }
  }
}

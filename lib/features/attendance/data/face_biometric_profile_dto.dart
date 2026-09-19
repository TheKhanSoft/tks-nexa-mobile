import 'dart:convert';

import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';

class FaceBiometricProfileDto {
  const FaceBiometricProfileDto._();

  static FaceBiometricProfile fromResponse(Object? response) {
    try {
      final root = _map(response);
      var data = root['data'] is Map ? _map(root['data']) : root;
      if (data['profile'] is Map) data = _map(data['profile']);

      final enrolled = data['enrolled'] ?? data['face_enrolled'];
      if (enrolled == false) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'No face biometric is enrolled for this employee.',
          diagnosticCode: 'FACE_NOT_ENROLLED',
        );
      }

      final employeeId =
          data['employee_id'] ?? data['user_id'] ?? data['subject_id'];
      final rawEmbedding =
          data['embedding'] ??
          data['embedding_vector'] ??
          data['face_embedding'];
      final threshold =
          data['match_threshold'] ??
          data['threshold'] ??
          data['min_similarity'];
      final modelVersion =
          data['model_version'] ?? data['embedding_model'] ?? data['model'];

      return FaceBiometricProfile(
        employeeId: employeeId?.toString() ?? '',
        embedding: _embedding(rawEmbedding),
        matchThreshold: threshold is num ? threshold.toDouble() : 0.78,
        modelVersion: modelVersion is String && modelVersion.trim().isNotEmpty
            ? modelVersion.trim()
            : 'mobile_facenet_512',
        livenessRequired:
            (data['liveness_required'] ?? data['require_liveness']) != false,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The enrolled face profile is incomplete or incompatible.',
        diagnosticCode: 'FACE_PROFILE_INVALID',
      );
    }
  }

  static List<double> _embedding(Object? value) {
    Object? decoded = value;
    if (value is String) decoded = jsonDecode(value);
    if (decoded is! List || decoded.length != 512) {
      throw const FormatException();
    }
    return decoded
        .map((item) {
          if (item is! num || !item.isFinite) throw const FormatException();
          return item.toDouble();
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}

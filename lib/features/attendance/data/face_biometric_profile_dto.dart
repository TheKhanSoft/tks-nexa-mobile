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

      final enrolled = data['enrolled'] ?? data['face_enrolled'] ?? data['is_enrolled'];
      if (enrolled == false) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'No face biometric is enrolled for this employee. Please enroll your face first.',
          diagnosticCode: 'FACE_NOT_ENROLLED',
        );
      }

      final employeeId =
          data['employee_id'] ?? data['user_id'] ?? data['subject_id'];
      if (employeeId == null || employeeId.toString().trim().isEmpty) {
        throw const AppFailure(
          code: FailureCode.invalidResponse,
          message: 'Employee identifier is missing from biometric profile.',
          diagnosticCode: 'EMPLOYEE_ID_MISSING',
        );
      }

      final photoUrl = data['photo_url'] ?? data['master_photo_url'] ?? data['picture_url'];
      final rawEmbedding =
          data['embedding'] ??
              data['embedding_vector'] ??
              data['face_embedding'] ??
              data['reference_embedding'];

      final hasEmbedding = rawEmbedding != null && (rawEmbedding is! List || rawEmbedding.isNotEmpty);
      final hasPhoto = photoUrl != null && photoUrl.toString().trim().isNotEmpty;

      if (!hasEmbedding && !hasPhoto) {
        throw const AppFailure(
          code: FailureCode.invalidInput,
          message: 'No face biometric is enrolled for this employee. Please enroll your face first.',
          diagnosticCode: 'FACE_NOT_ENROLLED',
        );
      }

      final threshold =
          data['match_threshold'] ??
              data['threshold'] ??
              data['min_similarity'];
      final modelVersion =
          data['model_version'] ?? data['embedding_model'] ?? data['model'];

      return FaceBiometricProfile(
        employeeId: employeeId.toString().trim(),
        embedding: _embedding(rawEmbedding),
        matchThreshold: threshold is num ? threshold.toDouble() : 0.70,
        modelVersion: modelVersion is String && modelVersion.trim().isNotEmpty
            ? modelVersion.trim()
            : 'Face Biometric (v1.0)',
        livenessRequired:
            (data['liveness_required'] ?? data['require_liveness']) != false,
        photoUrl: photoUrl?.toString().trim(),
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
    if (value == null) {
      return const <double>[];
    }
    Object? decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } catch (_) {
        return const <double>[];
      }
    }
    if (decoded is! List || decoded.isEmpty) {
      return const <double>[];
    }
    return decoded
        .map((item) {
      if (item is! num || !item.isFinite) return 0.0;
      return item.toDouble();
    })
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    throw const FormatException();
  }
}

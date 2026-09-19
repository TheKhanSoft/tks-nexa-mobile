import 'dart:convert';

import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_biometric_profile.dart';

class SecureBiometricProfileStore {
  const SecureBiometricProfileStore(this._storage, this._tenantCode);

  final SecureStorageService _storage;
  final String _tenantCode;

  String get _key =>
      'tenant:${_tenantCode.toLowerCase()}:face_biometric_profile';

  Future<void> save(FaceBiometricProfile profile) => _storage.write(
    _key,
    jsonEncode({
      'employee_id': profile.employeeId,
      'embedding': profile.embedding,
      'match_threshold': profile.matchThreshold,
      'model_version': profile.modelVersion,
      'liveness_required': profile.livenessRequired,
    }),
  );

  Future<FaceBiometricProfile?> read() async {
    final encoded = await _storage.read(_key);
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(value);
      final rawEmbedding = data['embedding'];
      if (rawEmbedding is! List) throw const FormatException();
      return FaceBiometricProfile(
        employeeId: data['employee_id']?.toString() ?? '',
        embedding: rawEmbedding
            .map((item) => (item as num).toDouble())
            .toList(growable: false),
        matchThreshold: (data['match_threshold'] as num).toDouble(),
        modelVersion: data['model_version'] as String,
        livenessRequired: data['liveness_required'] != false,
      );
    } on Object {
      await _storage.delete(_key);
      return null;
    }
  }
}

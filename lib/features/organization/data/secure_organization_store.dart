import 'dart:convert';

import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/organization/data/organization_dto.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_repository.dart';

class SecureOrganizationStore implements OrganizationStore {
  SecureOrganizationStore(this._storage, this._endpointValidator);

  static const _selectedOrganizationKey = 'app:selected_organization:v1';

  final SecureStorageService _storage;
  final TrustedEndpointValidator _endpointValidator;

  @override
  Future<void> clear() => _storage.delete(_selectedOrganizationKey);

  @override
  Future<Organization?> read() async {
    final value = await _storage.read(_selectedOrganizationKey);
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return OrganizationDto.fromStorageJson(
        decoded,
        endpointValidator: _endpointValidator,
      );
    } on Object {
      try {
        await clear();
      } on Object {
        // Preserve the original invalid-storage failure if cleanup also fails.
      }
      throw const AppFailure(
        code: FailureCode.storage,
        message: 'Saved organization data could not be restored.',
        diagnosticCode: 'ORG_STORAGE_INVALID',
      );
    }
  }

  @override
  Future<void> write(Organization organization) async {
    try {
      await _storage.write(
        _selectedOrganizationKey,
        jsonEncode(OrganizationDto.toStorageJson(organization)),
      );
    } on Object {
      throw const AppFailure(
        code: FailureCode.storage,
        message: 'The organization selection could not be saved securely.',
        diagnosticCode: 'ORG_STORAGE_WRITE_FAILED',
      );
    }
  }
}

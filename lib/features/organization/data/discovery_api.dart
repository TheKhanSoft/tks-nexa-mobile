import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/features/organization/data/organization_dto.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_code_parser.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_discovery_service.dart';

class DiscoveryApi implements OrganizationDiscoveryService {
  DiscoveryApi(this._dio, this._endpointValidator, this._discoveryBaseUri);

  static const String tenantListPath = 'mobile/v1/tenant-list';

  final Dio _dio;
  final TrustedEndpointValidator _endpointValidator;
  final Uri _discoveryBaseUri;

  @override
  Future<List<Organization>> fetchTenants({String? search}) async {
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.length > 100) {
      throw const AppFailure(
        code: FailureCode.invalidInput,
        message: 'The search text is too long.',
        diagnosticCode: 'TENANT_SEARCH_INVALID',
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        tenantListPath,
        queryParameters: normalizedSearch == null || normalizedSearch.isEmpty
            ? null
            : {'search': normalizedSearch},
      );
      final responseData = _asStringMap(response.data);
      if (responseData['status'] != 'success') throw _invalidResponse;
      final rawTenants = responseData['data'];
      if (rawTenants is! List<dynamic>) throw _invalidResponse;
      final tenants = rawTenants
          .map(_asStringMap)
          .map(
            (json) => OrganizationDto.fromTenantDirectoryJson(
              json,
              endpointValidator: _endpointValidator,
              discoveryBaseUri: _discoveryBaseUri,
            ),
          )
          .toList(growable: false);

      final count = responseData['count'];
      if (count != null && (count is! int || count != tenants.length)) {
        throw _invalidResponse;
      }
      return tenants;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<Organization> resolveByCode(String organizationCode) async {
    final code = const OrganizationCodeParser().parse(organizationCode);
    final organizations = await fetchTenants(search: code);
    for (final organization in organizations) {
      if (organization.code == code) return organization;
    }
    throw const AppFailure(
      code: FailureCode.notFound,
      message: 'No organization was found for that code.',
      diagnosticCode: 'ORG_NOT_FOUND',
    );
  }

  @override
  Future<List<Organization>> searchByName(String query) async {
    final normalizedQuery = query.trim();
    return fetchTenants(
      search: normalizedQuery.isEmpty ? null : normalizedQuery,
    );
  }

  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw _invalidResponse;
  }

  static AppFailure _mapDioException(DioException error) {
    if (kIsWeb && error.response == null) {
      return const AppFailure(
        code: FailureCode.unavailable,
        message: 'The browser could not read the organization directory.',
        diagnosticCode: 'TENANT_DIRECTORY_WEB_CORS_OR_NETWORK',
      );
    }
    return switch (error.response?.statusCode) {
      404 => const AppFailure(
        code: FailureCode.notFound,
        message: 'No organization was found for that code.',
        diagnosticCode: 'ORG_NOT_FOUND',
      ),
      422 => const AppFailure(
        code: FailureCode.invalidInput,
        message: 'Check the organization code and try again.',
        diagnosticCode: 'ORG_VALIDATION_FAILED',
      ),
      429 => const AppFailure(
        code: FailureCode.rateLimited,
        message: 'Too many attempts. Please wait and try again.',
        diagnosticCode: 'ORG_RATE_LIMITED',
      ),
      401 || 403 => const AppFailure(
        code: FailureCode.unavailable,
        message: 'This app build could not access the organization directory.',
        diagnosticCode: 'MOBILE_SIGNATURE_REJECTED',
      ),
      _ => const AppFailure(
        code: FailureCode.unavailable,
        message: 'The organization directory is temporarily unavailable.',
        diagnosticCode: 'TENANT_DIRECTORY_UNAVAILABLE',
      ),
    };
  }

  static const AppFailure _invalidResponse = AppFailure(
    code: FailureCode.invalidResponse,
    message: 'The organization directory returned an invalid response.',
    diagnosticCode: 'TENANT_DIRECTORY_RESPONSE_INVALID',
  );
}

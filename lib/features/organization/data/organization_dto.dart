import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_code_parser.dart';

class OrganizationDto {
  const OrganizationDto._();

  static Organization fromTenantDirectoryJson(
    Map<String, dynamic> json, {
    required TrustedEndpointValidator endpointValidator,
    required Uri discoveryBaseUri,
  }) {
    final publicId = json['public_id'] ?? json['id'];
    final name = json['name'];
    final status = json['status'];
    final domain = json['domain'];
    if (publicId is! String ||
        name is! String ||
        status != 'active' ||
        domain is! String) {
      throw _invalidResponse;
    }

    final normalizedDomain = domain.trim().toLowerCase();
    if (normalizedDomain.isEmpty ||
        normalizedDomain.contains('/') ||
        normalizedDomain.contains(':') ||
        normalizedDomain.contains('@') ||
        normalizedDomain.contains(RegExp(r'\s'))) {
      throw _invalidResponse;
    }

    final isLocalDomain =
        normalizedDomain == 'localhost' ||
        normalizedDomain.endsWith('.localhost');
    final apiBaseUri = Uri(
      scheme: isLocalDomain ? discoveryBaseUri.scheme : 'https',
      host: normalizedDomain,
      port: isLocalDomain && discoveryBaseUri.hasPort
          ? discoveryBaseUri.port
          : null,
      path: '/api/mobile',
    );
    return Organization(
      code: const OrganizationCodeParser().parse(publicId),
      name: _validateName(name),
      apiBaseUri: endpointValidator.validateTenantApiBaseUrl(
        apiBaseUri.toString(),
      ),
    );
  }

  static Organization fromDiscoveryJson(
    Map<String, dynamic> json, {
    required TrustedEndpointValidator endpointValidator,
    String? requestedCode,
  }) {
    final codeValue = json['code'] ?? requestedCode;
    final name = json['name'];
    final apiBaseUrl = json['api_base_url'];
    if (codeValue is! String || name is! String || apiBaseUrl is! String) {
      throw _invalidResponse;
    }

    final code = const OrganizationCodeParser().parse(codeValue);
    if (requestedCode != null && code != requestedCode) {
      throw _invalidResponse;
    }
    final logoValue = json['logo_url'];
    if (logoValue != null && logoValue is! String) {
      throw _invalidResponse;
    }

    return Organization(
      code: code,
      name: _validateName(name),
      apiBaseUri: endpointValidator.validateTenantApiBaseUrl(apiBaseUrl),
      logoUri: endpointValidator.validateOptionalHttpsUrl(logoValue as String?),
    );
  }

  static Map<String, dynamic> toStorageJson(Organization organization) {
    return {
      'version': 1,
      'code': organization.code,
      'name': organization.name,
      'api_base_url': organization.apiBaseUri.toString(),
      'logo_url': organization.logoUri?.toString(),
    };
  }

  static Organization fromStorageJson(
    Map<String, dynamic> json, {
    required TrustedEndpointValidator endpointValidator,
  }) {
    if (json['version'] != 1) throw _invalidResponse;
    return fromDiscoveryJson(json, endpointValidator: endpointValidator);
  }

  static String _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 160) throw _invalidResponse;
    return name;
  }

  static const AppFailure _invalidResponse = AppFailure(
    code: FailureCode.invalidResponse,
    message: 'The organization information was incomplete.',
    diagnosticCode: 'ORG_RESPONSE_INVALID',
  );
}

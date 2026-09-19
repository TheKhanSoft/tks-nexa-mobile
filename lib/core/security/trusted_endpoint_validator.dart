import 'package:tks_nexa_attendance/core/errors/app_failure.dart';

class TrustedEndpointValidator {
  TrustedEndpointValidator({
    required Set<String> allowedTenantHostSuffixes,
    this.allowDevelopmentLocalHttp = false,
  }) : _allowedTenantHostSuffixes = allowedTenantHostSuffixes
           .map((suffix) => suffix.toLowerCase())
           .toSet();

  final Set<String> _allowedTenantHostSuffixes;
  final bool allowDevelopmentLocalHttp;

  Uri validateTenantApiBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !_isAllowedScheme(uri) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_isAllowedHost(uri.host)) {
      throw const AppFailure(
        code: FailureCode.untrustedEndpoint,
        message: 'The organization returned an unapproved service address.',
        diagnosticCode: 'ORG_API_URL_REJECTED',
      );
    }
    return uri;
  }

  bool _isAllowedScheme(Uri uri) {
    if (uri.scheme == 'https') return true;
    if (!allowDevelopmentLocalHttp || uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host.endsWith('.localhost');
  }

  Uri? validateOptionalHttpsUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const AppFailure(
        code: FailureCode.invalidResponse,
        message: 'The organization information was incomplete.',
        diagnosticCode: 'ORG_LOGO_URL_INVALID',
      );
    }
    return uri;
  }

  bool _isAllowedHost(String host) {
    final normalizedHost = host.toLowerCase();
    return _allowedTenantHostSuffixes.any(
      (suffix) =>
          normalizedHost == suffix || normalizedHost.endsWith('.$suffix'),
    );
  }
}

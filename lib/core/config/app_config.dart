import 'package:flutter/foundation.dart';

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' => development,
      'staging' => staging,
      'production' => production,
      _ => throw const AppConfigurationException(
        'APP_ENV must be development, staging, or production.',
      ),
    };
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.discoveryBaseUri,
    required this.allowedTenantHostSuffixes,
    required this.mobileApiSecret,
    required this.allowMockSecurity,
    this.developmentConnectHost,
    this.developmentConnectPort,
    this.developmentConnectScheme = 'http',
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      environment: const String.fromEnvironment('APP_ENV'),
      discoveryBaseUrl: const String.fromEnvironment('DISCOVERY_BASE_URL'),
      tenantHostSuffixes: const String.fromEnvironment(
        'TENANT_API_ALLOWED_HOST_SUFFIXES',
      ),
      mobileApiSecret: const String.fromEnvironment('MOBILE_API_SECRET'),
      developmentConnectHost: const String.fromEnvironment(
        'DEVELOPMENT_CONNECT_HOST',
      ),
      developmentConnectPort: const String.fromEnvironment(
        'DEVELOPMENT_CONNECT_PORT',
      ),
      developmentConnectScheme: const String.fromEnvironment(
        'DEVELOPMENT_CONNECT_SCHEME',
        defaultValue: 'http',
      ),
      allowMockSecurity: const bool.fromEnvironment(
        'ALLOW_MOCK_SECURITY',
        defaultValue: false,
      ),
      isReleaseMode: kReleaseMode,
    );
  }

  factory AppConfig.fromValues({
    required String environment,
    required String discoveryBaseUrl,
    required String tenantHostSuffixes,
    required String mobileApiSecret,
    String developmentConnectHost = '',
    String developmentConnectPort = '',
    String developmentConnectScheme = 'http',
    bool allowMockSecurity = false,
    bool isReleaseMode = false,
  }) {
    final parsedEnvironment = AppEnvironment.parse(environment);
    final discoveryUri = Uri.tryParse(discoveryBaseUrl.trim());
    final isDevelopmentLocalHttp =
        parsedEnvironment == AppEnvironment.development &&
        discoveryUri?.scheme == 'http' &&
        _isLocalHost(discoveryUri?.host ?? '');
    if (discoveryUri == null ||
        (discoveryUri.scheme != 'https' && !isDevelopmentLocalHttp) ||
        discoveryUri.host.isEmpty ||
        discoveryUri.userInfo.isNotEmpty ||
        discoveryUri.hasQuery ||
        discoveryUri.hasFragment) {
      throw const AppConfigurationException(
        'DISCOVERY_BASE_URL must use HTTPS, except localhost in development.',
      );
    }
    final suffixes = tenantHostSuffixes
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (suffixes.isEmpty) {
      throw const AppConfigurationException(
        'TENANT_API_ALLOWED_HOST_SUFFIXES must not be empty.',
      );
    }
    for (final suffix in suffixes) {
      if (suffix.contains('/') ||
          suffix.contains(':') ||
          suffix.startsWith('.')) {
        throw const AppConfigurationException(
          'Tenant API host suffixes must be host names only.',
        );
      }
    }

    final normalizedMobileApiSecret = mobileApiSecret.trim();
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(normalizedMobileApiSecret)) {
      throw const AppConfigurationException(
        'MOBILE_API_SECRET must be a 64-character hexadecimal build secret.',
      );
    }

    if (isReleaseMode && allowMockSecurity) {
      throw const AppConfigurationException(
        'Mock security providers cannot be enabled in release builds.',
      );
    }
    if (isReleaseMode && parsedEnvironment != AppEnvironment.production) {
      throw const AppConfigurationException(
        'Release builds require APP_ENV=production.',
      );
    }

    final normalizedConnectHost = developmentConnectHost.trim();
    final normalizedConnectPort = developmentConnectPort.trim();
    final normalizedConnectScheme = developmentConnectScheme
        .trim()
        .toLowerCase();
    int? parsedConnectPort;
    if (normalizedConnectHost.isNotEmpty || normalizedConnectPort.isNotEmpty) {
      final connectUri = Uri.tryParse('http://$normalizedConnectHost');
      parsedConnectPort = int.tryParse(normalizedConnectPort);
      if (parsedEnvironment != AppEnvironment.development ||
          normalizedConnectHost.isEmpty ||
          connectUri == null ||
          connectUri.host != normalizedConnectHost ||
          connectUri.path.isNotEmpty ||
          parsedConnectPort == null ||
          parsedConnectPort < 1 ||
          parsedConnectPort > 65535) {
        throw const AppConfigurationException(
          'Development API bridge must have a valid host and TCP port and is allowed only in development.',
        );
      }
      if (normalizedConnectScheme != 'http' &&
          normalizedConnectScheme != 'https') {
        throw const AppConfigurationException(
          'Development API bridge scheme must be http or https.',
        );
      }
    }

    return AppConfig(
      environment: parsedEnvironment,
      discoveryBaseUri: discoveryUri,
      allowedTenantHostSuffixes: suffixes,
      mobileApiSecret: normalizedMobileApiSecret,
      allowMockSecurity: allowMockSecurity,
      developmentConnectHost: normalizedConnectHost.isEmpty
          ? null
          : normalizedConnectHost,
      developmentConnectPort: parsedConnectPort,
      developmentConnectScheme: normalizedConnectScheme,
    );
  }

  final AppEnvironment environment;
  final Uri discoveryBaseUri;
  final Set<String> allowedTenantHostSuffixes;
  final String mobileApiSecret;
  final bool allowMockSecurity;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final String developmentConnectScheme;

  bool get allowsLocalHttp => environment == AppEnvironment.development;

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' || normalized.endsWith('.localhost');
  }
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.safeMessage);

  final String safeMessage;

  @override
  String toString() => 'AppConfigurationException: $safeMessage';
}

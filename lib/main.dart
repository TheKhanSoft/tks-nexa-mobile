import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/app/app.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/core/network/dio_factory.dart';
import 'package:tks_nexa_attendance/core/security/trusted_endpoint_validator.dart';
import 'package:tks_nexa_attendance/core/storage/flutter_secure_storage_service.dart';
import 'package:tks_nexa_attendance/core/storage/development_web_ephemeral_storage.dart';
import 'package:tks_nexa_attendance/core/storage/secure_storage_service.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/data/discovery_api.dart';
import 'package:tks_nexa_attendance/features/organization/data/organization_repository_impl.dart';
import 'package:tks_nexa_attendance/features/organization/data/secure_organization_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = AppConfig.fromEnvironment();
    final platformSecureStorage = FlutterSecureStorageService();
    final SecureStorageService secureStorage =
        kIsWeb && config.environment == AppEnvironment.development
        ? DevelopmentWebEphemeralStorage(platformSecureStorage)
        : platformSecureStorage;
    final endpointValidator = TrustedEndpointValidator(
      allowedTenantHostSuffixes: config.allowedTenantHostSuffixes,
      allowDevelopmentLocalHttp: config.allowsLocalHttp,
    );
    final dio = DioFactory.createDiscoveryClient(config);
    final repository = OrganizationRepositoryImpl(
      DiscoveryApi(dio, endpointValidator, config.discoveryBaseUri),
      SecureOrganizationStore(secureStorage, endpointValidator),
    );

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
          organizationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const TksNexaApp(),
      ),
    );
  } on AppConfigurationException catch (error) {
    runApp(ConfigurationErrorApp(message: error.safeMessage));
  }
}

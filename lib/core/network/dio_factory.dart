import 'package:dio/dio.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/core/network/local_development_host_interceptor.dart';
import 'package:tks_nexa_attendance/core/network/mobile_request_signature_interceptor.dart';
import 'package:tks_nexa_attendance/core/network/safe_network_interceptor.dart';

class DioFactory {
  const DioFactory._();

  static Dio createDiscoveryClient(AppConfig config) {
    return _createSignedClient(
      config: config,
      baseUri: config.discoveryBaseUri,
    );
  }

  static Dio createTenantClient(AppConfig config, Uri tenantApiBaseUri) {
    // Keep the trusted tenant origin, but enforce the Laravel tenant route
    // contract independently from the central /mobile/v1 directory route.
    final tenantBaseUri = tenantApiBaseUri.replace(
      path: '/api/mobile',
      query: null,
      fragment: null,
    );
    return _createSignedClient(config: config, baseUri: tenantBaseUri);
  }

  static Dio _createSignedClient({
    required AppConfig config,
    required Uri baseUri,
  }) {
    final baseUrl = baseUri.toString().endsWith('/')
        ? baseUri.toString()
        : '${baseUri.toString()}/';
    return Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      )
      ..interceptors.addAll([
        if (config.allowsLocalHttp)
          LocalDevelopmentHostInterceptor(
            connectHost: config.developmentConnectHost,
            connectPort: config.developmentConnectPort,
          ),
        MobileRequestSignatureInterceptor(secret: config.mobileApiSecret),
        SafeNetworkInterceptor(),
      ]);
  }
}

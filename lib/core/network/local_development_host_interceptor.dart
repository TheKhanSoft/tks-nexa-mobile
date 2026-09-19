import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Connects local development subdomains through loopback while preserving the
/// logical Host header Laravel uses to resolve central and tenant domains.
class LocalDevelopmentHostInterceptor extends Interceptor {
  LocalDevelopmentHostInterceptor({this.connectHost, this.connectPort});

  final String? connectHost;
  final int? connectPort;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestUri = options.uri;
    final host = requestUri.host.toLowerCase();
    if (requestUri.scheme != 'http' || !host.endsWith('.localhost')) {
      handler.next(options);
      return;
    }

    // A browser on another device resolves *.localhost to that device. Route
    // development requests through the configured LAN bridge and carry the
    // validated logical Laravel host in a dedicated development header.
    if (kIsWeb) {
      final bridgeHost = connectHost?.trim();
      if (bridgeHost != null && bridgeHost.isNotEmpty && connectPort != null) {
        options.headers['X-Development-Host'] = requestUri.hasPort
            ? '${requestUri.host}:${requestUri.port}'
            : requestUri.host;
        options.baseUrl = Uri(
          scheme: requestUri.scheme,
          host: bridgeHost,
          port: connectPort,
        ).toString();
        options.path = requestUri.path;
      }
      handler.next(options);
      return;
    }

    options.headers['Host'] = requestUri.hasPort
        ? '${requestUri.host}:${requestUri.port}'
        : requestUri.host;
    options.baseUrl = Uri(
      scheme: requestUri.scheme,
      host: connectHost ?? 'localhost',
      port: connectPort ?? (requestUri.hasPort ? requestUri.port : null),
    ).toString();
    options.path = requestUri.path;
    handler.next(options);
  }
}

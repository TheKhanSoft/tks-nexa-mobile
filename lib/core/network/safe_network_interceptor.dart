import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class SafeNetworkInterceptor extends Interceptor {
  SafeNetworkInterceptor({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-ID', _uuid.v4);
    final logicalHost =
        options.headers['Host'] ??
        options.headers['X-Development-Host'] ??
        options.uri.authority;
    _log(
      'REQUEST ${options.method} ${options.uri.path} '
      'host=$logicalHost '
      'mobile_token=${options.headers.containsKey('X-Mobile-Token') ? 'attached' : 'missing'}',
      options,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(
      'RESPONSE ${response.statusCode ?? 0} '
      '${response.requestOptions.uri.path} '
      'content_type=${response.headers.value(Headers.contentTypeHeader) ?? 'unknown'}',
      response.requestOptions,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      'ERROR status=${err.response?.statusCode ?? 'none'} '
      'type=${err.type.name} ${err.requestOptions.uri.path}',
      err.requestOptions,
    );
    handler.next(err);
  }

  void _log(String message, RequestOptions options) {
    if (!kDebugMode) return;
    debugPrint(
      '[network] $message request_id=${options.headers['X-Request-ID']}',
    );
  }
}

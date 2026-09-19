import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

typedef EpochSecondsProvider = int Function();
typedef NonceGenerator = String Function();

/// Adds the backend's per-request mobile HMAC header.
///
/// This identifies requests made by a compatible app build. Because a shared
/// key in a client binary can be extracted, it must not be treated as user or
/// device authentication by the server.
class MobileRequestSignatureInterceptor extends Interceptor {
  MobileRequestSignatureInterceptor({
    required String secret,
    EpochSecondsProvider? epochSecondsProvider,
    NonceGenerator? nonceGenerator,
  }) : _secretBytes = utf8.encode(secret),
       _epochSecondsProvider = epochSecondsProvider ?? _utcEpochSeconds,
       _nonceGenerator = nonceGenerator ?? _secureNonce;

  final List<int> _secretBytes;
  final EpochSecondsProvider _epochSecondsProvider;
  final NonceGenerator _nonceGenerator;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final nonce = _nonceGenerator();
    final timestamp = _epochSecondsProvider().toString();
    final payload = utf8.encode('$nonce:$timestamp');
    final signature = Hmac(sha256, _secretBytes).convert(payload);
    options.headers['X-Mobile-Token'] = '$nonce.$timestamp.$signature';
    handler.next(options);
  }

  static int _utcEpochSeconds() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  static String _secureNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

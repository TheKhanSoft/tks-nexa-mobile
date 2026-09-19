import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tks_nexa_attendance/core/network/mobile_request_signature_interceptor.dart';

class _MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

void main() {
  test('adds the expected nonce timestamp and HMAC in one header', () {
    final interceptor = MobileRequestSignatureInterceptor(
      secret: 'test-secret',
      epochSecondsProvider: () => 1789623817,
      nonceGenerator: () => 'a7c39f1e84d2b6e5',
    );
    final options = RequestOptions(path: '/mobile/v1/tenant-list');
    final handler = _MockRequestInterceptorHandler();

    interceptor.onRequest(options, handler);

    expect(
      options.headers['X-Mobile-Token'],
      'a7c39f1e84d2b6e5.1789623817.'
      'd9c3161009c8006933c1480296dc8a4305bc61833489110ae11fe11766e6215b',
    );
    verify(() => handler.next(options)).called(1);
  });
}

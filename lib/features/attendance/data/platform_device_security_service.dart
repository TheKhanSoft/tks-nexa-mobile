import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/device_security_service.dart';

class PlatformDeviceSecurityService implements DeviceSecurityService {
  const PlatformDeviceSecurityService();

  static const _channel = MethodChannel(
    'com.tksnexa.attendance/device_security',
  );

  @override
  Future<DeviceKeyDetails?> getDeviceKey() async {
    if (kIsWeb) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'deviceKey',
      );
      if (result == null) return null;
      return DeviceKeyDetails(
        publicKey: _required(result['publicKey']),
        fingerprint: _required(result['fingerprint']),
        platform: _required(result['platform']),
        deviceModel: _required(result['deviceModel']),
        osVersion: _required(result['osVersion']),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<DeviceSecurityEvidence> createEvidence({
    required String canonicalPayload,
    required String integrityNonce,
    required bool requireIntegrity,
  }) async {
    if (kIsWeb) return const DeviceSecurityEvidence();

    String? signature;
    String? integrityToken;
    try {
      signature = await _channel.invokeMethod<String>('sign', {
        'payload': canonicalPayload,
      });
      if (requireIntegrity) {
        integrityToken = await _channel.invokeMethod<String>(
          'requestIntegrityToken',
          {'nonce': integrityNonce},
        );
      }
    } on PlatformException {
      // The server policy decides whether unavailable platform evidence can be
      // accepted. Never fabricate a device signature or integrity verdict.
    } on MissingPluginException {
      // Desktop and unsupported development targets have no hardware service.
    }
    return DeviceSecurityEvidence(
      signature: _nonEmpty(signature),
      integrityToken: _nonEmpty(integrityToken),
    );
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String _required(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw const FormatException('Incomplete device key response.');
  }
}

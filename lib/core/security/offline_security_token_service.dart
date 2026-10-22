import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class OfflineSecurityTokenService {
  const OfflineSecurityTokenService._();

  /// Encrypts and cryptographically signs an offline attendance security payload
  /// using AES-256-CBC and HMAC-SHA256 with the shared mobile API secret.
  ///
  /// The resulting hidden token cannot be read, altered, or forged by the employee
  /// even if they inspect request traffic or modify device wall-clock settings.
  static String createToken({
    required Map<String, dynamic> payload,
    required String secret,
  }) {
    final secretBytes = utf8.encode(secret.trim());
    final keyBytes = Uint8List.fromList(sha256.convert(secretBytes).bytes);

    // 16-byte cryptographically secure random IV
    final random = Random.secure();
    final ivBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );

    // AES-256-CBC encryption with PKCS7 padding
    final jsonStr = jsonEncode(payload);
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(jsonStr, iv: enc.IV(ivBytes));

    // Combine IV (16 bytes) + Ciphertext
    final ivAndCipher = Uint8List.fromList([
      ...ivBytes,
      ...encrypted.bytes,
    ]);

    // HMAC-SHA256 signature across IV + Ciphertext
    final hmac = Hmac(sha256, secretBytes).convert(ivAndCipher);

    // Base64URL-encoded envelope + dot + hex signature
    final envelope = base64Url.encode(ivAndCipher);
    return '$envelope.${hmac.toString()}';
  }

  /// Verifies the HMAC-SHA256 signature and decrypts the AES-256-CBC payload.
  /// Returns null if the token has been tampered with or corrupted.
  static Map<String, dynamic>? verifyAndDecryptToken({
    required String token,
    required String secret,
  }) {
    final parts = token.trim().split('.');
    if (parts.length != 2) return null;

    final envelopeBase64 = parts[0];
    final signatureHex = parts[1].toLowerCase();

    Uint8List ivAndCipher;
    try {
      ivAndCipher = base64Url.decode(envelopeBase64);
    } catch (_) {
      try {
        ivAndCipher = base64.decode(base64.normalize(envelopeBase64));
      } catch (_) {
        return null;
      }
    }

    if (ivAndCipher.length < 17) return null;

    final secretBytes = utf8.encode(secret.trim());
    final expectedHmac = Hmac(sha256, secretBytes).convert(ivAndCipher).toString().toLowerCase();

    if (expectedHmac != signatureHex) {
      return null; // Signature mismatch / payload tampered
    }

    final keyBytes = Uint8List.fromList(sha256.convert(secretBytes).bytes);
    final ivBytes = Uint8List.sublistView(ivAndCipher, 0, 16);
    final cipherBytes = Uint8List.sublistView(ivAndCipher, 16);

    try {
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc),
      );
      final decrypted = encrypter.decrypt(
        enc.Encrypted(cipherBytes),
        iv: enc.IV(ivBytes),
      );
      final decoded = jsonDecode(decrypted);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

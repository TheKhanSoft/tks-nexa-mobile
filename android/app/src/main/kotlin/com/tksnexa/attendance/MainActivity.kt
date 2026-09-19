package com.tksnexa.attendance

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.tksnexa.attendance/device_security"
    private val keyAlias = "tks_nexa_attendance_device_signing_v1"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sign" -> {
                        val payload = call.argument<String>("payload")
                        if (payload.isNullOrBlank()) {
                            result.error("INVALID_PAYLOAD", "A canonical payload is required.", null)
                            return@setMethodCallHandler
                        }
                        runCatching { sign(payload) }
                            .onSuccess(result::success)
                            .onFailure {
                                result.error("DEVICE_SIGNING_FAILED", "Hardware-backed signing failed.", null)
                            }
                    }

                    "deviceKey" -> runCatching { deviceKeyDetails() }
                        .onSuccess(result::success)
                        .onFailure {
                            result.error("DEVICE_KEY_FAILED", "The device key could not be created.", null)
                        }

                    "requestIntegrityToken" -> {
                        val nonce = call.argument<String>("nonce")
                        if (nonce.isNullOrBlank()) {
                            result.error("INVALID_NONCE", "An integrity nonce is required.", null)
                            return@setMethodCallHandler
                        }
                        IntegrityManagerFactory.create(applicationContext)
                            .requestIntegrityToken(
                                IntegrityTokenRequest.builder().setNonce(nonce).build(),
                            )
                            .addOnSuccessListener { response -> result.success(response.token()) }
                            .addOnFailureListener {
                                result.error(
                                    "PLAY_INTEGRITY_UNAVAILABLE",
                                    "Google Play Integrity could not issue a token.",
                                    null,
                                )
                            }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sign(payload: String): String {
        ensureKey()
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = keyStore.getKey(keyAlias, null)
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey as java.security.PrivateKey)
        signature.update(payload.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(signature.sign(), Base64.NO_WRAP)
    }

    private fun deviceKeyDetails(): Map<String, Any> {
        ensureKey()
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val certificate = keyStore.getCertificate(keyAlias)
        val encoded = certificate.publicKey.encoded
        val body = Base64.encodeToString(encoded, Base64.NO_WRAP)
            .chunked(64)
            .joinToString("\n")
        val fingerprint = MessageDigest.getInstance("SHA-256")
            .digest(encoded)
            .joinToString("") { "%02x".format(it) }
        return mapOf(
            "publicKey" to "-----BEGIN PUBLIC KEY-----\n$body\n-----END PUBLIC KEY-----",
            "fingerprint" to fingerprint,
            "platform" to "android",
            "deviceModel" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}",
            "osVersion" to "Android ${android.os.Build.VERSION.RELEASE}",
        )
    }

    private fun ensureKey() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (keyStore.containsAlias(keyAlias)) return

        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore",
        )
        generator.initialize(
            KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(false)
                .build(),
        )
        generator.generateKeyPair()
    }
}

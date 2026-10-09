package com.tksnexa.thekhansoft

import android.content.Intent
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.FileProvider
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.tksnexa.thekhansoft/device_security"
    private val keyAlias = "tks_nexa_attendance_device_signing_v1"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareToWhatsApp" -> {
                        val filePath = call.argument<String>("filePath")
                        val caption = call.argument<String>("caption") ?: ""
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_FILE", "File path is required.", null)
                            return@setMethodCallHandler
                        }
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }

                        val authority = "${applicationContext.packageName}.flutter.share_provider"
                        val uri = try {
                            FileProvider.getUriForFile(applicationContext, authority, file)
                        } catch (e: Exception) {
                            result.error("FILE_URI_FAILED", "Failed to resolve FileProvider URI: ${e.message}", null)
                            return@setMethodCallHandler
                        }

                        val pm = applicationContext.packageManager
                        val isWhatsAppInstalled = runCatching { pm.getPackageInfo("com.whatsapp", 0) }.isSuccess
                        val isW4bInstalled = runCatching { pm.getPackageInfo("com.whatsapp.w4b", 0) }.isSuccess

                        val targetPackage = when {
                            isWhatsAppInstalled -> "com.whatsapp"
                            isW4bInstalled -> "com.whatsapp.w4b"
                            else -> null
                        }

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (caption.isNotBlank()) {
                                putExtra(Intent.EXTRA_TEXT, caption)
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (targetPackage != null) {
                                setPackage(targetPackage)
                            }
                        }

                        try {
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val chooser = Intent.createChooser(intent, "Share via WhatsApp")
                                activity.startActivity(chooser)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("SHARE_FAILED", "Unable to share image: ${e2.message}", null)
                            }
                        }
                    }

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

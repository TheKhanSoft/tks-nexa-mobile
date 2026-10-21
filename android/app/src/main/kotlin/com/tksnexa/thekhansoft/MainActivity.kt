package com.tksnexa.thekhansoft

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.scottyab.rootbeer.RootBeer
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
    private val notificationChannelName = "com.tksnexa.thekhansoft/notifications"
    private val keyAlias = "tks_nexa_attendance_device_signing_v1"
    private val REQUEST_POST_NOTIFICATIONS = 1102
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure high-importance notification channel is registered on startup
        ShiftReminderReceiver.createNotificationChannel(applicationContext)

        // Device Security & Hardware Attestation Channel
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

                    "checkDeviceSecurity" -> {
                        runCatching { checkDeviceSecurity() }
                            .onSuccess(result::success)
                            .onFailure {
                                result.success(
                                    mapOf(
                                        "isRooted" to false,
                                        "isHooked" to false,
                                        "isTampered" to false,
                                        "details" to ""
                                    )
                                )
                            }
                    }

                    "getWifiDetails" -> {
                        runCatching { getWifiDetails() }
                            .onSuccess(result::success)
                            .onFailure {
                                result.success(
                                    mapOf(
                                        "isWifiConnected" to false,
                                        "bssid" to null,
                                        "ssid" to null,
                                        "gatewayIp" to null
                                    )
                                )
                            }
                    }

                    else -> result.notImplemented()
                }
            }

        // Local Notifications & Exact Alarm Scheduling Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasNotificationPermission" -> {
                        val areEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                        result.success(areEnabled)
                    }

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                result.success(true)
                            } else {
                                notificationPermissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_POST_NOTIFICATIONS)
                            }
                        } else {
                            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                        }
                    }

                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: 1000
                        val title = call.argument<String>("title") ?: "TKS Nexa"
                        val message = call.argument<String>("message") ?: ""
                        showImmediateNotification(id, title, message, result)
                    }

                    "scheduleAlarm" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val triggerAtMillis = (call.argument<Number>("triggerAtMillis")?.toLong()) ?: 0L
                        val title = call.argument<String>("title") ?: "Shift Reminder"
                        val message = call.argument<String>("message") ?: "Time for your shift."
                        scheduleShiftAlarm(id, triggerAtMillis, title, message, result)
                    }

                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        cancelShiftAlarm(id)
                        result.success(true)
                    }

                    "openNotificationSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                            } else {
                                Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = android.net.Uri.fromParts("package", packageName, null)
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "cancelAllAlarms" -> {
                        cancelShiftAlarm(1001)
                        cancelShiftAlarm(1002)
                        cancelShiftAlarm(1003)
                        cancelShiftAlarm(1004)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            notificationPermissionResult?.success(granted)
            notificationPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun showImmediateNotification(id: Int, title: String, message: String, result: MethodChannel.Result) {
        ShiftReminderReceiver.createNotificationChannel(applicationContext)

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, id, launchIntent, flags)

        val iconRes = if (resources.getIdentifier("ic_notification", "drawable", packageName) != 0) {
            R.drawable.ic_notification
        } else {
            applicationInfo.icon
        }

        val notification = NotificationCompat.Builder(this, ShiftReminderReceiver.CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setColor(0xFF2563EB.toInt())
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(id, notification)
            result.success(true)
        } catch (e: Exception) {
            result.error("NOTIFICATION_FAILED", e.message, null)
        }
    }

    private fun scheduleShiftAlarm(id: Int, triggerAtMillis: Long, title: String, message: String, result: MethodChannel.Result) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            result.error("ALARM_ERROR", "AlarmManager unavailable", null)
            return
        }

        val intent = Intent(applicationContext, ShiftReminderReceiver::class.java).apply {
            action = ShiftReminderReceiver.ACTION_SHIFT_REMINDER
            putExtra("id", id)
            putExtra("title", title)
            putExtra("message", message)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getBroadcast(applicationContext, id, intent, flags)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SCHEDULE_FAILED", e.message, null)
        }
    }

    private fun cancelShiftAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(applicationContext, ShiftReminderReceiver::class.java).apply {
            action = ShiftReminderReceiver.ACTION_SHIFT_REMINDER
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getBroadcast(applicationContext, id, intent, flags)
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
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

    private fun checkDeviceSecurity(): Map<String, Any> {
        val rootBeer = RootBeer(applicationContext)
        val isRootBeer = rootBeer.isRooted
        val isBusyBox = rootBeer.isRootedWithBusyBoxCheck

        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/data/su",
            "/system/su"
        )
        val suFound = suPaths.any { path ->
            runCatching { File(path).exists() }.getOrDefault(false)
        }

        val magiskFound = runCatching {
            File("/proc/mounts").readLines().any { line ->
                line.contains("magisk", ignoreCase = true) ||
                line.contains("core/mirror", ignoreCase = true) ||
                line.contains("core/img", ignoreCase = true)
            }
        }.getOrDefault(false)

        val isTestKeys = android.os.Build.TAGS?.contains("test-keys") == true

        // Hooking checks (Xposed, LSPosed, Frida)
        val hookClasses = arrayOf(
            "de.robv.android.xposed.XposedBridge",
            "de.robv.android.xposed.XC_MethodHook",
            "com.saurik.substrate.MS\$MethodHook",
            "me.weishu.exposed.XposedBridge",
            "org.lsposed.lspd.nativebridge.LSPHost"
        )
        val hookClassesFound = hookClasses.any { cls ->
            runCatching { Class.forName(cls) }.isSuccess
        }

        val mapsTampered = runCatching {
            File("/proc/self/maps").readLines().any { line ->
                line.contains("frida", ignoreCase = true) ||
                line.contains("xposed", ignoreCase = true) ||
                line.contains("lsposed", ignoreCase = true)
            }
        }.getOrDefault(false)

        val stackHookFound = Exception().stackTrace.any { elem ->
            elem.className.contains("xposed", ignoreCase = true) ||
            elem.className.contains("lsposed", ignoreCase = true)
        }

        val isRooted = isRootBeer || isBusyBox || suFound || magiskFound || isTestKeys
        val isHooked = hookClassesFound || mapsTampered || stackHookFound
        val isTampered = isRooted || isHooked

        val flags = mutableListOf<String>()
        if (isRootBeer) flags.add("rootbeer")
        if (isBusyBox) flags.add("busybox")
        if (suFound) flags.add("su_binary")
        if (magiskFound) flags.add("magisk_mount")
        if (isTestKeys) flags.add("test_keys")
        if (hookClassesFound) flags.add("xposed_class")
        if (mapsTampered) flags.add("maps_hook")
        if (stackHookFound) flags.add("stack_hook")

        return mapOf(
            "isRooted" to isRooted,
            "isHooked" to isHooked,
            "isTampered" to isTampered,
            "details" to flags.joinToString(",")
        )
    }

    private fun getWifiDetails(): Map<String, Any?> {
        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val network = connectivityManager?.activeNetwork
        val capabilities = connectivityManager?.getNetworkCapabilities(network)
        val isWifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

        if (!isWifi) {
            return mapOf(
                "isWifiConnected" to false,
                "bssid" to null,
                "ssid" to null,
                "gatewayIp" to null
            )
        }

        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val info = wifiManager?.connectionInfo

        var bssid = info?.bssid
        if (bssid.isNullOrBlank() || bssid == "02:00:00:00:00:00") {
            bssid = null
        }

        var ssid = info?.ssid
        if (ssid != null) {
            ssid = ssid.removePrefix("\"").removeSuffix("\"")
            if (ssid == "<unknown ssid>" || ssid.isBlank()) {
                ssid = null
            }
        }

        var gatewayIp: String? = null
        val dhcpInfo = wifiManager?.dhcpInfo
        if (dhcpInfo != null && dhcpInfo.gateway != 0) {
            val ip = dhcpInfo.gateway
            gatewayIp = "%d.%d.%d.%d".format(
                ip and 0xFF,
                ip shr 8 and 0xFF,
                ip shr 16 and 0xFF,
                ip shr 24 and 0xFF
            )
        }

        return mapOf(
            "isWifiConnected" to true,
            "bssid" to bssid,
            "ssid" to ssid,
            "gatewayIp" to gatewayIp
        )
    }
}

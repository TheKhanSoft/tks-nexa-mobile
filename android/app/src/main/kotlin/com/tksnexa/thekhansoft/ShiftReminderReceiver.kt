package com.tksnexa.thekhansoft

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ShiftReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_SHIFT_REMINDER = "com.tksnexa.thekhansoft.ACTION_SHIFT_REMINDER"
        const val CHANNEL_ID = "tks_nexa_shift_reminders"
        const val CHANNEL_NAME = "Shift & Attendance Reminders"

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Timely reminders before scheduled shifts and missing clock-outs."
                    enableLights(true)
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Android OS clears exact alarms on reboot. The Flutter app
            // will re-synchronize upcoming alarms upon launch.
            return
        }

        if (intent.action == ACTION_SHIFT_REMINDER) {
            val id = intent.getIntExtra("id", 1001)
            val title = intent.getStringExtra("title") ?: "Shift Reminder"
            val message = intent.getStringExtra("message") ?: "Time to mark your attendance."

            createNotificationChannel(context)

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(
                context,
                MainActivity::class.java
            )
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getActivity(context, id, launchIntent, flags)

            val iconRes = if (context.resources.getIdentifier("ic_notification", "drawable", context.packageName) != 0) {
                R.drawable.ic_notification
            } else {
                context.applicationInfo.icon
            }

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
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
                NotificationManagerCompat.from(context).notify(id, notification)
            } catch (_: SecurityException) {
                // If notification permission was revoked on Android 13+
            }
        }
    }
}

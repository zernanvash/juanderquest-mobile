package dev.zernanvash.juanderquest

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Plan 124d: local "arrived near the next stop" notification for a trail running in the
 * background. Tapping it reopens MainActivity (singleTop) and the tap is sent to Dart
 * (`onTap`), or kept for `takeLaunchTap` when the tap launched the app.
 * Silently does nothing when notifications are not allowed.
 */
class TrailNotificationBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val CHANNEL = "dev.zernanvash.juanderquest/trail_notifications"
        private const val NOTIFICATION_CHANNEL_ID = "jdq_trail_alerts"
        private const val EXTRA_TAP = "jdq_trail_tap"
        private const val EXTRA_TRAIL_ID = "jdq_trail_id"
        private const val EXTRA_STOP = "jdq_trail_stop"
        private const val NOTIFICATION_ID_BASE = 52400
    }

    private val context: Context = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingTap: Map<String, Any>? = null
    private val shownIds = mutableSetOf<Int>()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    show(
                        title = call.argument<String>("title") ?: "Trail stop nearby",
                        body = call.argument<String>("body") ?: "",
                        trailId = call.argument<String>("trailId") ?: "",
                        stopPosition = call.argument<Int>("stopPosition") ?: 0,
                    )
                    result.success(null)
                }
                "cancelAll" -> {
                    val manager = NotificationManagerCompat.from(context)
                    for (id in shownIds) manager.cancel(id)
                    shownIds.clear()
                    result.success(null)
                }
                "takeLaunchTap" -> {
                    result.success(pendingTap)
                    pendingTap = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Called with the launch intent and every new intent. */
    fun handleIntent(intent: Intent?) {
        if (intent == null || !intent.getBooleanExtra(EXTRA_TAP, false)) return
        val tap = mapOf<String, Any>(
            "trailId" to (intent.getStringExtra(EXTRA_TRAIL_ID) ?: ""),
            "stopPosition" to intent.getIntExtra(EXTRA_STOP, 0),
        )
        intent.removeExtra(EXTRA_TAP)
        pendingTap = tap
        channel.invokeMethod("onTap", tap, object : MethodChannel.Result {
            override fun success(result: Any?) {
                pendingTap = null
            }

            override fun error(code: String, message: String?, details: Any?) {}

            override fun notImplemented() {}
        })
    }

    private fun show(title: String, body: String, trailId: String, stopPosition: Int) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Trail stop alerts",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_TAP, true)
            putExtra(EXTRA_TRAIL_ID, trailId)
            putExtra(EXTRA_STOP, stopPosition)
        }
        val id = NOTIFICATION_ID_BASE + stopPosition
        val pending = PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
            shownIds.add(id)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the post.
        }
    }
}

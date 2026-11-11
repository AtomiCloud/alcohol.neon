package cloud.atomi.alcohol_neon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors

/**
 * Android's counterpart of the iOS "Next up" Live Activity: an ongoing
 * notification for the next open habit, with a system countdown to its
 * deadline, today's progress and a Complete action. On Android 16 it asks to
 * be promoted to a Live Update (status-bar chip, top of the shade, lock
 * screen). Driven by the same `neon/live_activity` channel as iOS.
 */
object NextUpNotification {
    private const val CHANNEL_ID = "next_up"
    private const val NOTIFICATION_ID = 7201
    private const val STATE = "next_up_state"
    // Written by home_widget's saveWidgetData (WidgetService.cacheAuth).
    private const val AUTH = "HomeWidgetPreferences"

    enum class Phase { OPEN, SAVING, DONE, FAILED }

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "neon/live_activity").setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    @Suppress("UNCHECKED_CAST")
                    val a = call.arguments as? Map<String, Any?>
                    val versionId = a?.get("versionId") as? String
                    val name = a?.get("name") as? String
                    val deadline = (a?.get("deadlineMs") as? Number)?.toLong()
                    if (versionId != null && name != null && deadline != null) {
                        app.getSharedPreferences(STATE, Context.MODE_PRIVATE).edit()
                            .putString("versionId", versionId)
                            .putString("name", name)
                            .putLong("deadline", deadline)
                            .putString("stake", a["stake"] as? String)
                            .putInt("done", (a["done"] as? Number)?.toInt() ?: 0)
                            .putInt("total", (a["total"] as? Number)?.toInt() ?: 0)
                            .putString("phase", Phase.OPEN.name)
                            .apply()
                        post(app)
                    }
                    result.success(null)
                }
                "end" -> {
                    end(app)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun end(context: Context) {
        context.getSharedPreferences(STATE, Context.MODE_PRIVATE).edit().clear().apply()
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }

    /** Sets the phase of the shown habit (if it's still [versionId]) and re-posts. */
    fun setPhase(context: Context, versionId: String, phase: Phase) {
        val prefs = context.getSharedPreferences(STATE, Context.MODE_PRIVATE)
        if (prefs.getString("versionId", null) != versionId) return
        val edit = prefs.edit().putString("phase", phase.name)
        if (phase == Phase.DONE && prefs.getString("phase", null) != Phase.DONE.name) {
            edit.putInt("done", minOf(prefs.getInt("total", 0), prefs.getInt("done", 0) + 1))
        }
        edit.apply()
        post(context)
    }

    private fun post(context: Context) {
        val prefs = context.getSharedPreferences(STATE, Context.MODE_PRIVATE)
        val versionId = prefs.getString("versionId", null) ?: return
        val name = prefs.getString("name", null) ?: return
        val deadline = prefs.getLong("deadline", 0)
        val stake = prefs.getString("stake", null)
        val done = prefs.getInt("done", 0)
        val total = prefs.getInt("total", 0)
        val phase = runCatching { Phase.valueOf(prefs.getString("phase", "OPEN")!!) }
            .getOrDefault(Phase.OPEN)

        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            // Default importance: Live Updates aren't promoted from MIN/LOW channels.
            val channel = NotificationChannel(
                CHANNEL_ID, "Next up", NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Your next habit and the time left to do it."
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        val open = PendingIntent.getActivity(
            context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val emerald = Color.parseColor("#059669")
        val status = when (phase) {
            Phase.OPEN -> stake ?: "$done of $total done today"
            Phase.SAVING -> "Saving…"
            Phase.DONE -> "Done · $done of $total today"
            Phase.FAILED -> "Couldn't save. Try again."
        }
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(name)
            .setContentText(status)
            .setSubText("Next up")
            .setColor(emerald)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(deadline)
            .setUsesChronometer(phase != Phase.DONE)
            .setChronometerCountDown(true)
            .setTimeoutAfter(maxOf(1L, deadline - System.currentTimeMillis()))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)

        if (phase == Phase.OPEN || phase == Phase.FAILED) {
            val complete = PendingIntent.getBroadcast(
                context, versionId.hashCode(),
                Intent(context, CompleteHabitReceiver::class.java).putExtra("versionId", versionId),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            builder.addAction(
                Notification.Action.Builder(
                    null, if (phase == Phase.FAILED) "Try again" else "Complete", complete,
                ).build(),
            )
        }

        if (Build.VERSION.SDK_INT >= 36 && total > 0) {
            // Android 16: one segment per habit scheduled today, filled as they're done.
            // Styled by progress (the default), so segments past `done` are dimmed.
            builder.setStyle(
                Notification.ProgressStyle()
                    .setProgressSegments(
                        List(total) { Notification.ProgressStyle.Segment(1).setColor(emerald) },
                    )
                    .setProgress(done),
            )
        }
        // Ask Android 16+ to promote this to a Live Update. Older versions
        // ignore the extra and show a normal ongoing notification.
        builder.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })

        nm.notify(NOTIFICATION_ID, builder.build())
    }

    /**
     * POST {zinc_base}/api/v1.0/Habit/{uid}/{versionId}/executions with the
     * cached bearer token, like the iOS widget's CompleteHabitIntent.
     */
    fun completeOnServer(context: Context, versionId: String): Boolean {
        val prefs = context.getSharedPreferences(AUTH, Context.MODE_PRIVATE)
        val base = prefs.getString("zinc_base", null) ?: return false
        val token = prefs.getString("zinc_token", null) ?: return false
        val uid = prefs.getString("zinc_uid", null) ?: return false
        return try {
            val root = URI(base)
            val url = URI(root.scheme, root.authority, "/api/v1.0/Habit/$uid/$versionId/executions", null, null).toURL()
            val conn = url.openConnection() as HttpURLConnection
            try {
                conn.requestMethod = "POST"
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000
                conn.doOutput = true
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
                conn.responseCode in 200..299
            } finally {
                conn.disconnect()
            }
        } catch (_: Exception) {
            false
        }
    }
}

/** The notification's Complete action: confirm-first, Done only once zinc has it. */
class CompleteHabitReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val versionId = intent.getStringExtra("versionId") ?: return
        val app = context.applicationContext
        NextUpNotification.setPhase(app, versionId, NextUpNotification.Phase.SAVING)
        val pending = goAsync()
        io.execute {
            try {
                val ok = NextUpNotification.completeOnServer(app, versionId)
                NextUpNotification.setPhase(
                    app, versionId,
                    if (ok) NextUpNotification.Phase.DONE else NextUpNotification.Phase.FAILED,
                )
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        val io = Executors.newSingleThreadExecutor()
    }
}

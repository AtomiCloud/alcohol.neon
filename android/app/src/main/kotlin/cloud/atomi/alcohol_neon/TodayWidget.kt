package cloud.atomi.alcohol_neon

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * Android's counterpart of the iOS glass "Today" widget (ios/NeonWidget):
 * - [NextUpWidget] (2x2): the next open habit, a countdown to its deadline,
 *   its proof and today's ring.
 * - [TodayWidget] (4x2): today's ring plus as many open habits as its height
 *   fits; check-in habits get a Complete button, NFC habits show the tag icon.
 * Both read the `today_schedule` JSON the app writes through home_widget
 * (WidgetService.sync), the same payload the iOS widget reads.
 */
object TodayWidgets {
    // home_widget's saveWidgetData store on Android.
    private const val PREFS = "HomeWidgetPreferences"
    private const val DATA = "today_schedule"
    private const val ACTION_COMPLETE = "cloud.atomi.alcohol_neon.widget.COMPLETE"
    private const val ACTION_REFRESH = "cloud.atomi.alcohol_neon.widget.REFRESH"

    data class Habit(val id: String, val name: String, val deadline: Long, val nfc: Boolean)
    data class Day(val done: Int, val total: Int, val open: List<Habit>)

    /** Today's plan, with habits whose check has already closed left out. */
    fun load(context: Context, now: Long = System.currentTimeMillis()): Day? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(DATA, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val items = json.optJSONArray("items")
            val open = mutableListOf<Habit>()
            for (i in 0 until (items?.length() ?: 0)) {
                val it = items!!.getJSONObject(i)
                if (it.optBoolean("done")) continue
                val deadline = parseUtc(it.optString("deadline")) ?: continue
                if (deadline <= now) continue
                open += Habit(
                    id = it.optString("id"),
                    name = it.optString("name", "Habit"),
                    deadline = deadline,
                    nfc = it.optString("proof") == "nfc",
                )
            }
            Day(json.optInt("done"), json.optInt("total"), open.sortedBy { it.deadline })
        } catch (_: Exception) {
            null
        }
    }

    private fun parseUtc(s: String): Long? {
        for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'")) {
            val f = SimpleDateFormat(pattern, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
            runCatching { return f.parse(s)?.time }
        }
        return null
    }

    private fun hm(ms: Long) = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(ms))

    private fun pendingId(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("pending_id", null)

    /** Redraws every placed widget of both sizes. */
    fun refreshAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        for (id in mgr.getAppWidgetIds(ComponentName(context, NextUpWidget::class.java))) {
            mgr.updateAppWidget(id, nextUp(context))
        }
        for (id in mgr.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))) {
            // Portrait height; 0 before the launcher has reported a size.
            val height = mgr.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            mgr.updateAppWidget(id, today(context, height))
        }
        scheduleNextRefresh(context)
    }

    /**
     * Wakes the widgets when the next deadline passes so a closed habit drops off.
     * Inexact (no exact-alarm permission); updatePeriodMillis backs it up.
     */
    private fun scheduleNextRefresh(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, WidgetActionReceiver::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val next = load(context)?.open?.firstOrNull()?.deadline
        if (next == null) am.cancel(pi) else am.set(AlarmManager.RTC, next + 1_000, pi)
    }

    private fun openApp(context: Context) = PendingIntent.getActivity(
        context, 0,
        context.packageManager.getLaunchIntentForPackage(context.packageName),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun completeIntent(context: Context, versionId: String) = PendingIntent.getBroadcast(
        context, versionId.hashCode(),
        Intent(context, WidgetActionReceiver::class.java)
            .setAction(ACTION_COMPLETE)
            .putExtra("versionId", versionId),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun ring(views: RemoteViews, day: Day?) {
        val total = day?.total ?: 0
        views.setProgressBar(R.id.ring, maxOf(total, 1), day?.done ?: 0, false)
    }

    /** Elapsed-realtime base that makes a Chronometer count down to [deadline]. */
    private fun countdownBase(deadline: Long) =
        SystemClock.elapsedRealtime() + (deadline - System.currentTimeMillis())

    fun nextUp(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_next_up)
        views.setOnClickPendingIntent(R.id.root, openApp(context))
        val day = load(context)
        ring(views, day)
        val next = day?.open?.firstOrNull()
        if (next == null) {
            views.setTextViewText(R.id.label, if (day == null) "LazyTax" else "Today")
            views.setTextViewText(
                R.id.name,
                when {
                    day == null -> "Open the app"
                    day.total == 0 -> "Nothing today"
                    else -> "All done"
                },
            )
            views.setViewVisibility(R.id.countdown_row, View.GONE)
            views.setTextViewText(R.id.proof, day?.let { "${it.done}/${it.total} done" } ?: "")
            views.setViewVisibility(R.id.proof_icon, View.GONE)
            return views
        }
        views.setTextViewText(R.id.label, "Next up")
        views.setTextViewText(R.id.name, next.name)
        views.setViewVisibility(R.id.countdown_row, View.VISIBLE)
        views.setChronometer(R.id.countdown, countdownBase(next.deadline), "%s left", true)
        views.setChronometerCountDown(R.id.countdown, true)
        views.setViewVisibility(R.id.proof_icon, View.VISIBLE)
        views.setImageViewResource(
            R.id.proof_icon, if (next.nfc) R.drawable.widget_ic_nfc else R.drawable.widget_ic_check,
        )
        views.setTextViewText(
            R.id.proof,
            if (pendingId(context) == next.id) "Saving…" else "${proofLabel(next)} · by ${hm(next.deadline)}",
        )
        return views
    }

    private fun proofLabel(habit: Habit) = if (habit.nfc) "NFC tag" else "Check-in"

    // widget_today: 16dp padding top and bottom, a 40dp row, an 18dp "+N more" line.
    private const val ROW_DP = 40
    private const val MORE_DP = 18

    /** What the 4x2 says when no habit is open: signed out, nothing scheduled, or all done. */
    internal fun emptyMessage(day: Day?) = when {
        day == null -> "Open LazyTax to load today"
        day.total == 0 -> "No habits today"
        else -> "Nothing left today"
    }

    /** How many open habits a 4x2 of [heightDp] shows, leaving room for "+N more" if needed. */
    internal fun rowsThatFit(heightDp: Int, open: Int): Int {
        if (heightDp <= 0) return minOf(open, 3)
        // Launchers report a little more than they draw (233dp for a 222dp 4x2 on a Pixel).
        val usable = heightDp - 32 - 12
        return if (open <= usable / ROW_DP) open else maxOf(1, (usable - MORE_DP) / ROW_DP)
    }

    fun today(context: Context, heightDp: Int = 0): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        views.setOnClickPendingIntent(R.id.root, openApp(context))
        val day = load(context)
        ring(views, day)
        views.setTextViewText(R.id.count, day?.let { "${it.done}/${it.total}" } ?: "–")
        val open = day?.open.orEmpty()
        val next = when {
            open.isNotEmpty() -> "Next by ${hm(open.first().deadline)}"
            day != null && day.total > 0 -> "All done"
            else -> null
        }
        views.setTextViewText(R.id.next, next ?: "")
        views.setViewVisibility(R.id.next, if (next == null) View.GONE else View.VISIBLE)

        val shown = rowsThatFit(heightDp, open.size)
        val pending = pendingId(context)
        views.removeAllViews(R.id.rows)
        for (habit in open.take(shown)) {
            val row = RemoteViews(context.packageName, R.layout.widget_today_row)
            row.setTextViewText(R.id.row_name, habit.name)
            val saving = pending == habit.id
            row.setTextViewText(
                R.id.row_sub,
                if (saving) "Saving…" else "${proofLabel(habit)} · by ${hm(habit.deadline)}",
            )
            if (habit.nfc) {
                // An NFC habit needs a scan in the app; tapping the icon opens it.
                row.setImageViewResource(R.id.row_button, R.drawable.widget_ic_nfc)
                row.setContentDescription(R.id.row_button, "Open LazyTax to scan for ${habit.name}")
                row.setOnClickPendingIntent(R.id.row_button, openApp(context))
            } else {
                row.setImageViewResource(
                    R.id.row_button, if (saving) R.drawable.widget_circle_saving else R.drawable.widget_circle,
                )
                row.setContentDescription(R.id.row_button, if (saving) "Saving ${habit.name}" else "Complete ${habit.name}")
                row.setOnClickPendingIntent(R.id.row_button, completeIntent(context, habit.id))
            }
            views.addView(R.id.rows, row)
        }
        val hidden = open.size - shown
        views.setTextViewText(R.id.more, "+$hidden more")
        views.setViewVisibility(R.id.more, if (hidden > 0) View.VISIBLE else View.GONE)

        views.setTextViewText(R.id.empty, emptyMessage(day))
        views.setViewVisibility(R.id.empty, if (open.isEmpty()) View.VISIBLE else View.GONE)
        return views
    }

    /**
     * Confirm-first, like the notification's Complete: "Saving…" until zinc has
     * the completion, then the habit moves to done; on failure it stays open.
     */
    fun complete(context: Context, versionId: String, onDone: () -> Unit) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString("pending_id", versionId).apply()
        refreshAll(context)
        NextUpNotification.setPhase(context, versionId, NextUpNotification.Phase.SAVING)
        io.execute {
            try {
                val ok = NextUpNotification.completeOnServer(context, versionId)
                prefs.edit().remove("pending_id").apply()
                if (ok) markDone(context, versionId)
                NextUpNotification.setPhase(
                    context, versionId,
                    if (ok) NextUpNotification.Phase.DONE else NextUpNotification.Phase.FAILED,
                )
                refreshAll(context)
            } finally {
                onDone()
            }
        }
    }

    /** Flips [versionId] to done in the stored plan (also used by the notification). */
    fun markDone(context: Context, versionId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(DATA, null) ?: return
        try {
            val json = JSONObject(raw)
            val items = json.optJSONArray("items") ?: return
            for (i in 0 until items.length()) {
                val it = items.getJSONObject(i)
                if (it.optString("id") == versionId && !it.optBoolean("done")) {
                    it.put("done", true)
                    json.put("done", minOf(json.optInt("total"), json.optInt("done") + 1))
                    prefs.edit().putString(DATA, json.toString()).apply()
                    return
                }
            }
        } catch (_: Exception) {
            // Malformed payload; the next app sync rewrites it.
        }
    }

    const val COMPLETE = ACTION_COMPLETE
    private val io = Executors.newSingleThreadExecutor()
}

/** 2x2 "Next up" widget. */
class NextUpWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) =
        TodayWidgets.refreshAll(context)
}

/** 4x2 "Today" widget. */
class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) =
        TodayWidgets.refreshAll(context)

    /** Resized: redraw so the number of habit rows matches the new height. */
    override fun onAppWidgetOptionsChanged(context: Context, mgr: AppWidgetManager, id: Int, options: Bundle) =
        TodayWidgets.refreshAll(context)
}

/** The widgets' Complete buttons and the deadline refresh alarm. */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        if (intent.action != TodayWidgets.COMPLETE) {
            TodayWidgets.refreshAll(app)
            return
        }
        val versionId = intent.getStringExtra("versionId") ?: return
        val pending = goAsync()
        TodayWidgets.complete(app, versionId) { pending.finish() }
    }
}

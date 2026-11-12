package cloud.atomi.alcohol_neon

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The 4x2 "Today" widget's layout logic. Expected row counts come from
 * widget_today.xml: 16dp padding top and bottom, 40dp per habit row, 18dp for
 * the "+N more" line, and 12dp kept spare because launchers report a little
 * more height than they draw.
 */
class TodayWidgetsTest {
    @Test
    fun `a Pixel 4x2 shows four habits and leaves room for +N more`() {
        // 233dp reported: 233 - 32 - 12 = 189dp, four 40dp rows, plus 18dp for "+1 more".
        assertEquals(4, TodayWidgets.rowsThatFit(233, 5))
        assertEquals(4, TodayWidgets.rowsThatFit(233, 10))
    }

    @Test
    fun `every habit shows when they all fit, with no +N more line`() {
        assertEquals(4, TodayWidgets.rowsThatFit(233, 4))
        assertEquals(2, TodayWidgets.rowsThatFit(233, 2))
    }

    @Test
    fun `the +N more line takes the place of a row that would otherwise fit`() {
        // 204dp: 160dp usable fits exactly four rows, but four rows plus
        // "+N more" (178dp) don't, so five habits show as three and "+2 more".
        assertEquals(4, TodayWidgets.rowsThatFit(204, 4))
        assertEquals(3, TodayWidgets.rowsThatFit(204, 5))
    }

    @Test
    fun `a taller widget shows more habits`() {
        // 4x3-sized: 340 - 44 = 296dp usable fits seven rows.
        assertEquals(6, TodayWidgets.rowsThatFit(340, 6))
        assertEquals(6, TodayWidgets.rowsThatFit(340, 9))
    }

    @Test
    fun `a widget too short for any row still shows one`() {
        assertEquals(1, TodayWidgets.rowsThatFit(90, 3))
    }

    @Test
    fun `before the launcher reports a size it shows up to three`() {
        assertEquals(3, TodayWidgets.rowsThatFit(0, 5))
        assertEquals(2, TodayWidgets.rowsThatFit(0, 2))
    }

    private val read = TodayWidgets.Habit("v-read", "Read", deadline = 0L, nfc = false)
    private val gym = TodayWidgets.Habit("v-gym", "Gym", deadline = 0L, nfc = true)

    @Test
    fun `a habit whose Complete failed says so, like the notification`() {
        assertEquals("Couldn't save. Try again.", TodayWidgets.habitStatus(read, pendingId = null, failedId = "v-read"))
    }

    @Test
    fun `the failure shows only on the habit that failed`() {
        val other = TodayWidgets.habitStatus(gym, pendingId = null, failedId = "v-read")
        assertTrue(other, other.startsWith("NFC tag · by "))
        val plain = TodayWidgets.habitStatus(read, pendingId = null, failedId = null)
        assertTrue(plain, plain.startsWith("Check-in · by "))
    }

    @Test
    fun `a retry in flight shows Saving, not the old failure`() {
        assertEquals("Saving…", TodayWidgets.habitStatus(read, pendingId = "v-read", failedId = "v-read"))
    }

    @Test
    fun `the empty message tells signed out, nothing scheduled and all done apart`() {
        assertEquals("Open LazyTax to load today", TodayWidgets.emptyMessage(null))
        assertEquals("No habits today", TodayWidgets.emptyMessage(TodayWidgets.Day(0, 0, emptyList())))
        assertEquals("Nothing left today", TodayWidgets.emptyMessage(TodayWidgets.Day(3, 3, emptyList())))
    }
}

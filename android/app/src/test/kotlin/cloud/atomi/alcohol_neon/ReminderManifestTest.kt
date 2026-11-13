package cloud.atomi.alcohol_neon

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

/**
 * Habit reminders are AlarmManager alarms that flutter_local_notifications
 * delivers to its own receivers, which the app manifest must declare (the
 * plugin's manifest doesn't). Without them no scheduled reminder ever shows.
 */
class ReminderManifestTest {
    private val android = "http://schemas.android.com/apk/res/android"
    private val manifest = DocumentBuilderFactory.newInstance()
        .apply { isNamespaceAware = true }
        .newDocumentBuilder()
        .parse(File("src/main/AndroidManifest.xml"))

    private fun elements(tag: String): List<Element> {
        val nodes = manifest.getElementsByTagName(tag)
        return (0 until nodes.length).map { nodes.item(it) as Element }
    }

    private fun receiver(name: String): Element? =
        elements("receiver").firstOrNull { it.getAttributeNS(android, "name") == name }

    @Test
    fun `scheduled reminders have a receiver to post them`() {
        assertTrue(
            receiver("com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver") != null,
        )
    }

    @Test
    fun `reminders are re-scheduled after a reboot`() {
        val boot = receiver(
            "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
        )
        val actions = boot?.getElementsByTagName("action")?.let { nodes ->
            (0 until nodes.length).map { (nodes.item(it) as Element).getAttributeNS(android, "name") }
        }.orEmpty()
        assertTrue(actions.contains("android.intent.action.BOOT_COMPLETED"))
        assertTrue(
            elements("uses-permission").any {
                it.getAttributeNS(android, "name") == "android.permission.RECEIVE_BOOT_COMPLETED"
            },
        )
    }
}

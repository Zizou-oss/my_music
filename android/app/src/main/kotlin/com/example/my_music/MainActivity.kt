package com.example.my_music

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "2BLOCK_NOTIF"
        private const val NOTIFICATION_ACTION = "SELECT_NOTIFICATION"
        private const val FALLBACK_UPDATE_URL = "https://2block-web-ctth.vercel.app/"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenBehavior()
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.action != NOTIFICATION_ACTION) return

        val extras = intent.extras ?: return
        val payloadCandidate = sequenceOf(
            extras.getString("payload"),
            extras.getString("notificationResponse"),
            extras.getString("data"),
            extras.keySet().joinToString(separator = ";") { key ->
                "$key=${extras.get(key)}"
            }
        ).firstOrNull { !it.isNullOrBlank() } ?: return

        val payload = payloadCandidate.lowercase()
        val isAppUpdate = payload.contains("notification_type=app_update") ||
            payload.contains("\"notification_type\":\"app_update\"") ||
            payload.contains("topic=app_updates") ||
            payload.contains("\"topic\":\"app_updates\"")
        if (!isAppUpdate) return

        val targetUrl = extractUrl(payloadCandidate) ?: FALLBACK_UPDATE_URL
        Log.d(TAG, "Notification tap app_update -> open url: $targetUrl")
        try {
            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(targetUrl)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(browserIntent)
        } catch (_: Exception) {
            // Ignore if no browser is available.
        }
    }

    private fun extractUrl(raw: String): String? {
        val regex = Regex("""https?://[^\s"'}]+""")
        return regex.find(raw)?.value
    }

    private fun configureLockScreenBehavior() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
}

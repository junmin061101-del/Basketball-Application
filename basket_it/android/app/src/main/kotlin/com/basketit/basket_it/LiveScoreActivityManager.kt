package com.basketit.basket_it

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import android.util.LruCache
import android.view.View
import android.widget.RemoteViews
import com.istornz.live_activities.LiveActivityManager
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * 서버(functions/live-score.js)가 보낸 경기 상태로 잠금화면 스코어 알림을 그린다.
 *
 * 받는 값: league, homeName, awayName, homeScore, awayScore, period("3쿼터"),
 * clock("7:12"), status("live" | "final"), homeLogo, awayLogo.
 * 로고는 "asset:assets/logos/kbl/sk.png"(앱에 넣은 KBL 아이콘) 또는 https 주소(NBA).
 */
class LiveScoreActivityManager(context: Context) : LiveActivityManager(context) {
    private val appContext = context.applicationContext

    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): Notification {
        val homeName = text(data, "homeName")
        val awayName = text(data, "awayName")
        val homeScore = number(data, "homeScore")
        val awayScore = number(data, "awayScore")
        val isFinal = text(data, "status") == "final"
        val league = if (text(data, "league") == "kbl") "KBL" else "NBA"
        val status = listOf(text(data, "period"), text(data, "clock"))
            .filter { it.isNotEmpty() }
            .joinToString(" · ")

        val views = RemoteViews(appContext.packageName, R.layout.live_score_notification)
        views.setTextViewText(R.id.live_score_league, league)
        views.setTextViewText(R.id.live_score_status, status)
        views.setTextViewText(R.id.live_score_home_name, homeName)
        views.setTextViewText(R.id.live_score_away_name, awayName)
        views.setTextViewText(R.id.live_score_home_score, homeScore)
        views.setTextViewText(R.id.live_score_away_score, awayScore)
        setLogo(views, R.id.live_score_home_logo, text(data, "homeLogo"))
        setLogo(views, R.id.live_score_away_logo, text(data, "awayLogo"))

        val launch = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                appContext, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        notification
            .setSmallIcon(R.drawable.ic_stat_live_score)
            // 커스텀 뷰를 못 그리는 곳(워치·접근성 등)에서 보이는 글자.
            .setContentTitle("$homeName $homeScore : $awayScore $awayName")
            .setContentText(status)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            // 진행 중에는 밀어도 지워지지 않고, 끝나면 최종 점수를 15분 보여준 뒤 내린다.
            .setOngoing(!isFinal)
            .setAutoCancel(isFinal)
        if (isFinal) notification.setTimeoutAfter(FINAL_VISIBLE_MS)
        contentIntent?.let { notification.setContentIntent(it) }
        return notification.build()
    }

    private fun setLogo(views: RemoteViews, viewId: Int, source: String) {
        val bitmap = loadLogo(source)
        if (bitmap == null) {
            views.setViewVisibility(viewId, View.GONE)
        } else {
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setImageViewBitmap(viewId, bitmap)
        }
    }

    private fun loadLogo(source: String): Bitmap? {
        if (source.isEmpty()) return null
        memory.get(source)?.let { return it }
        val bitmap = try {
            when {
                source.startsWith("asset:") ->
                    appContext.assets.open("flutter_assets/" + source.removePrefix("asset:"))
                        .use { decodeScaled(it.readBytes()) }
                source.startsWith("https://") -> decodeScaled(download(source) ?: return null)
                else -> null
            }
        } catch (e: Exception) {
            Log.w(TAG, "로고를 불러오지 못했습니다: $source", e)
            null
        }
        bitmap?.let { memory.put(source, it) }
        return bitmap
    }

    /** 한 번 받은 NBA 로고는 캐시 폴더에 두어 30초마다 다시 받지 않는다. */
    private fun download(url: String): ByteArray? {
        val dir = File(appContext.cacheDir, "live_score_logos").apply { mkdirs() }
        val file = File(dir, sha1(url) + ".img")
        if (file.exists() && file.length() > 0) return file.readBytes()
        val connection = URL(url).openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            if (connection.responseCode != 200) return null
            val bytes = connection.inputStream.use { it.readBytes() }
            file.writeBytes(bytes)
            bytes
        } finally {
            connection.disconnect()
        }
    }

    private fun decodeScaled(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= LOGO_PX && bounds.outHeight / (sample * 2) >= LOGO_PX) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }
        ) ?: return null
        if (decoded.width <= LOGO_PX && decoded.height <= LOGO_PX) return decoded
        val scale = LOGO_PX.toFloat() / maxOf(decoded.width, decoded.height)
        return Bitmap.createScaledBitmap(
            decoded,
            (decoded.width * scale).toInt().coerceAtLeast(1),
            (decoded.height * scale).toInt().coerceAtLeast(1),
            true
        )
    }

    private fun text(data: Map<String, Any>, key: String): String {
        val value = data[key] ?: return ""
        return if (value == org.json.JSONObject.NULL) "" else value.toString()
    }

    private fun number(data: Map<String, Any>, key: String): String =
        (data[key] as? Number)?.toInt()?.toString() ?: text(data, key).ifEmpty { "0" }

    private fun sha1(input: String): String =
        MessageDigest.getInstance("SHA-1").digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }

    companion object {
        const val CHANNEL_NAME = "실시간 경기 스코어"
        const val CHANNEL_DESCRIPTION = "팔로우한 팀 경기의 점수·쿼터·남은 시간을 잠금화면에 보여줍니다"
        private const val TAG = "LiveScore"
        private const val LOGO_PX = 96
        private const val FINAL_VISIBLE_MS = 15 * 60 * 1000L
        private val memory = LruCache<String, Bitmap>(40)
    }
}

package com.basketit.basket_it

import android.app.Application
import com.istornz.live_activities.LiveActivityManagerHolder

/**
 * 앱이 꺼져 있을 때 FCM이 프로세스를 깨워도 잠금화면 스코어를 그릴 수 있도록,
 * Flutter 엔진보다 먼저 알림 채널과 매니저를 준비한다.
 */
class BasketItApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val manager = LiveScoreActivityManager(this)
        manager.initialize(
            mapOf(
                "liveActivityChannelName" to LiveScoreActivityManager.CHANNEL_NAME,
                "liveActivityChannelDescription" to LiveScoreActivityManager.CHANNEL_DESCRIPTION,
            )
        )
        LiveActivityManagerHolder.instance = manager
    }
}

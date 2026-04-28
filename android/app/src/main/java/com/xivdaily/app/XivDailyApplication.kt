package com.xivdaily.app

import android.app.Application
import com.xivdaily.app.di.AppContainer

class XivDailyApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        // 先集中创建依赖容器，后续页面与 ViewModel 都从这里拿实例。
        container = AppContainer(this)
    }
}


package com.yf.f260729_lan_chat

import com.yf.f260729_lan_chat.multicast.MulticastLockApiImpl
import com.yf.f260729_lan_chat.pigeon.MulticastLockApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var multicastLockApi: MulticastLockApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val api = MulticastLockApiImpl(applicationContext)
        multicastLockApi = api
        MulticastLockApi.setUp(flutterEngine.dartExecutor.binaryMessenger, api)
    }

    override fun onDestroy() {
        multicastLockApi?.release()
        multicastLockApi = null
        super.onDestroy()
    }
}

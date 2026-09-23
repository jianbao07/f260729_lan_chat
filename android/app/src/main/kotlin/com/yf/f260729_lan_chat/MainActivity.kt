package com.yf.f260729_lan_chat

import android.content.Intent
import com.yf.f260729_lan_chat.multicast.MulticastLockApiImpl
import com.yf.f260729_lan_chat.pigeon.MulticastLockApi
import com.yf.f260729_lan_chat.share.ShareIntentHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var multicastLockApi: MulticastLockApiImpl? = null
    private var shareIntentHandler: ShareIntentHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val api = MulticastLockApiImpl(applicationContext)
        multicastLockApi = api
        MulticastLockApi.setUp(flutterEngine.dartExecutor.binaryMessenger, api)
        val share = ShareIntentHandler(this, flutterEngine.dartExecutor.binaryMessenger)
        shareIntentHandler = share
        share.consume(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareIntentHandler?.consume(intent)
    }

    override fun onDestroy() {
        multicastLockApi?.release()
        multicastLockApi = null
        shareIntentHandler = null
        super.onDestroy()
    }
}

package com.yf.f260729_lan_chat.multicast

import android.content.Context
import android.net.wifi.WifiManager
import com.yf.f260729_lan_chat.pigeon.MulticastLockApi

class MulticastLockApiImpl(
    private val context: Context,
) : MulticastLockApi {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun acquire(): Boolean {
        if (multicastLock?.isHeld == true) return true
        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return false
        val lock = multicastLock ?: wifiManager.createMulticastLock("yf_code_udp_beat").also {
            it.setReferenceCounted(false)
            multicastLock = it
        }
        lock.acquire()
        return lock.isHeld
    }

    override fun release() {
        val lock = multicastLock ?: return
        if (lock.isHeld) {
            lock.release()
        }
    }

    override fun isHeld(): Boolean = multicastLock?.isHeld == true
}

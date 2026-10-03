package com.partilha.partilha

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the platform side of [MulticastLock].
 *
 * Android drops multicast traffic for an app that has not acquired
 * `WifiManager.MulticastLock`, and it does so silently: discovery returns
 * nothing, which is indistinguishable from an empty network. The lock also
 * costs power, so it is reference counted here and held only while discovery
 * runs.
 */
class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        acquireMulticastLock()
                        result.success(null)
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Acquires the lock, or increments its hold count when already held.
     *
     * `isReferenceCounted` is left at its default of true, so concurrent
     * acquire/release pairs nest correctly instead of the second release
     * dropping a lock the first caller still needs.
     */
    private fun acquireMulticastLock() {
        val current = lock ?: run {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiManager.createMulticastLock(LOCK_TAG).also {
                it.setReferenceCounted(true)
            }
        }
        current.acquire()
        lock = current
    }

    /**
     * Releases one hold, dropping the reference once nothing holds the lock.
     *
     * With reference counting enabled, [WifiManager.MulticastLock.isHeld] stays
     * true until every acquire has a matching release, so it is what decides
     * whether the lock can be discarded.
     */
    private fun releaseMulticastLock() {
        val current = lock ?: return
        if (current.isHeld) {
            current.release()
        }
        if (!current.isHeld) {
            lock = null
        }
    }

    override fun onDestroy() {
        // A lock leaked past the activity would keep the Wi-Fi radio awake for
        // the rest of the process lifetime.
        lock?.let { if (it.isHeld) it.release() }
        lock = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "partilha/multicast_lock"
        const val LOCK_TAG = "partilha-discovery"
    }
}
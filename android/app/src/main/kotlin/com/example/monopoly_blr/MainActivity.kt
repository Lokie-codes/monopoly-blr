package com.example.monopoly_blr

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        lock = wifi.createMulticastLock("monopolyLock")
        lock?.setReferenceCounted(true)
        lock?.acquire()
    }

    override fun onDestroy() {
        super.onDestroy()
        lock?.release()
    }
}

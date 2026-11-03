package de.muktadir.ruhrtransit

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Sends `true` while the default network reaches the internet and `false`
 * otherwise, first the current state, then every change.
 *
 * "Reaches the internet" is Android's VALIDATED capability: a Wi-Fi with a
 * captive portal (station Wi-Fi before logging in) counts as offline.
 */
class ConnectivityStreamHandler(context: Context) : EventChannel.StreamHandler {

  private val manager = context.getSystemService(ConnectivityManager::class.java)
  private val main = Handler(Looper.getMainLooper())
  private var callback: ConnectivityManager.NetworkCallback? = null
  private var last: Boolean? = null

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    fun send(online: Boolean) {
      main.post {
        // Callbacks repeat themselves; Flutter only needs changes.
        if (online != last) {
          last = online
          events.success(online)
        }
      }
    }

    send(isOnline(manager.getNetworkCapabilities(manager.activeNetwork)))
    callback = object : ConnectivityManager.NetworkCallback() {
      override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
        send(isOnline(capabilities))
      }

      override fun onLost(network: Network) {
        send(false)
      }
    }.also { manager.registerDefaultNetworkCallback(it) }
  }

  override fun onCancel(arguments: Any?) {
    callback?.let { manager.unregisterNetworkCallback(it) }
    callback = null
    last = null
  }

  private fun isOnline(capabilities: NetworkCapabilities?) =
      capabilities != null &&
          capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
          capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
}

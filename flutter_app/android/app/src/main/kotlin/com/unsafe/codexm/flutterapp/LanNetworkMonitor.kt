package com.unsafe.codexm.flutterapp

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.net.Inet4Address

class LanNetworkMonitor(context: Context) {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var registered = false

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = emitSnapshot()
        override fun onLost(network: Network) = emitSnapshot()
        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) = emitSnapshot()
        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties,
        ) = emitSnapshot()
    }

    fun start(events: EventChannel.EventSink) {
        eventSink = events
        if (!registered) {
            val request = NetworkRequest.Builder().build()
            connectivityManager.registerNetworkCallback(request, callback)
            registered = true
        }
        emitSnapshot()
    }

    fun stop() {
        eventSink = null
        if (registered) {
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (_: Throwable) {
            }
            registered = false
        }
    }

    fun snapshot(): Map<String, Any> {
        val addresses = ArrayList<String>()
        for (network in connectivityManager.allNetworks) {
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: continue
            val isLanTransport =
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
            if (!isLanTransport) continue
            val linkProperties = connectivityManager.getLinkProperties(network) ?: continue
            linkProperties.linkAddresses
                .map { value -> value.address }
                .filterIsInstance<Inet4Address>()
                .filter(::isPrivateLanAddress)
                .map { value -> value.hostAddress.orEmpty() }
                .filter { value -> value.isNotBlank() }
                .forEach(addresses::add)
        }
        return mapOf("addresses" to addresses.distinct())
    }

    private fun emitSnapshot() {
        mainHandler.post { eventSink?.success(snapshot()) }
    }

    private fun isPrivateLanAddress(address: Inet4Address): Boolean {
        if (address.isAnyLocalAddress || address.isLoopbackAddress) return false
        if (address.isSiteLocalAddress || address.isLinkLocalAddress) return true
        val bytes = address.address.map { value -> value.toInt() and 0xff }
        return bytes[0] == 100 && bytes[1] in 64..127
    }
}

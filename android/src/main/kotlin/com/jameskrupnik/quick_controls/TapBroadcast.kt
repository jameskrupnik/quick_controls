package com.jameskrupnik.quick_controls

import android.content.Context
import android.content.Intent

/**
 * Tells the host app that a tile recorded a tap, whether or not its Flutter
 * engine is running.
 *
 * [PingBus] only reaches a running engine, and most tile taps happen when
 * there is none. A host that shows the same number somewhere else — Stitch
 * Keeper's home screen widget adds the pending taps to its count — has no
 * other way to learn it should redraw. So after every recorded tap the tile
 * sends this broadcast, **scoped to the host's own package** so no other app
 * can hear it. Declare a receiver with an intent filter for [ACTION] to get
 * it; `android:exported="false"` is enough, since the sender is the same app.
 *
 * It carries the control id in [EXTRA_CONTROL_ID], never the event: the
 * pending log is still the only place a tap lives.
 *
 * The fields are worked out free of Android types, like [TileDisplay], so the
 * scoping is unit tested; [send] only copies them onto an `Intent`.
 */
data class TapBroadcast(val action: String, val packageName: String, val controlId: String) {
    fun send(context: Context) {
        context.sendBroadcast(
            Intent(action).setPackage(packageName).putExtra(EXTRA_CONTROL_ID, controlId),
        )
    }

    companion object {
        const val ACTION = "com.jameskrupnik.quick_controls.action.TAP_RECORDED"
        const val EXTRA_CONTROL_ID = "controlId"

        /** The broadcast for a tap on [controlId] in the app [packageName]. */
        fun of(packageName: String, controlId: String) = TapBroadcast(ACTION, packageName, controlId)
    }
}

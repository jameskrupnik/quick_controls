package com.jameskrupnik.quick_controls

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * The link from a tile to a running Flutter engine, if there is one.
 *
 * It carries a ping — "something was recorded" — and never the event itself.
 * Dart answers a ping by draining, so an event reaches Dart only through the
 * drain, and the drain's lock is the only thing that has to be right for a
 * tap to be delivered exactly once.
 *
 * A static is correct here, not a shortcut: the tile service and the plugin
 * share a process (see the manifest) but not an object graph, and the tile
 * must not start an engine just to say it was tapped.
 *
 * ### One process, several engines
 *
 * Every engine in the process — a background isolate started by
 * `firebase_messaging`, `workmanager` or `home_widget` as well as the app's
 * own — attaches its own plugin instance. So the sink remembers which
 * instance set it, and only that one may clear it: otherwise a background
 * engine shutting down would silence the app's live pings.
 */
object PingBus {
    private val main by lazy { Handler(Looper.getMainLooper()) }

    private var owner: Any? = null

    @Volatile
    var sink: EventChannel.EventSink? = null
        private set

    /** [owner]'s engine is listening, through [sink]. The newest listener wins. */
    @Synchronized
    fun listen(owner: Any, sink: EventChannel.EventSink?) {
        this.owner = owner
        this.sink = sink
    }

    /** [owner] stopped listening or detached. A no-op unless it set the sink. */
    @Synchronized
    fun release(owner: Any) {
        if (this.owner !== owner) return
        this.owner = null
        sink = null
    }

    fun ping(controlId: String) {
        main.post { sink?.success(mapOf("controlId" to controlId)) }
    }
}

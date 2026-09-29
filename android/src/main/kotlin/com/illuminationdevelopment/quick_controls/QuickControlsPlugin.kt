package com.illuminationdevelopment.quick_controls

import android.app.StatusBarManager
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.TileService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of `QuickControls`: one method channel for commands, one
 * event channel for "something was tapped" pings.
 *
 * Every method is answered synchronously except `requestAddTile`, whose
 * answer comes from a system dialog.
 */
class QuickControlsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var store: QuickControlsStore
    private var methods: MethodChannel? = null
    private var pings: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        store = QuickControlsStore(context)
        methods = MethodChannel(binding.binaryMessenger, "quick_controls").also { it.setMethodCallHandler(this) }
        pings = EventChannel(binding.binaryMessenger, "quick_controls/pings").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        pings?.setStreamHandler(null)
        methods = null
        pings = null
        PingBus.release(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        PingBus.listen(this, events)
    }

    override fun onCancel(arguments: Any?) {
        PingBus.release(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
            "initialize" -> initialize(call, result)
            "setValue" -> {
                val id = call.argument<String>("id")!!
                store.setValue(id, (call.argument<Number>("value") ?: 0).toLong())
                refresh(id)
                result.success(null)
            }
            "setToggled" -> {
                val id = call.argument<String>("id")!!
                store.setToggled(id, call.argument<Boolean>("isOn") ?: false)
                refresh(id)
                result.success(null)
            }
            "drainPendingEvents" -> result.success(store.events.drain().map { it.toChannel() })
            "reload" -> {
                val id = call.argument<String>("id")
                if (id != null) refresh(id) else store.slots().keys.forEach(::refresh)
                result.success(null)
            }
            "requestAddTile" -> requestAddTile(call.argument<String>("id")!!, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<List<Any?>>("controls") ?: emptyList()
        val controls = raw.map { ControlConfig.fromChannel(it) }
        if (controls.any { it == null }) {
            result.error("bad_control", "A control could not be read: $raw", null)
            return
        }
        try {
            store.declare(controls.filterNotNull())
        } catch (e: TooManyControlsException) {
            result.error("too_many_controls", e.message, null)
            return
        }
        store.slots().keys.forEach(::refresh)
        result.success(null)
    }

    /**
     * Asks SystemUI to rebind the tile so `onStartListening` redraws it. A
     * no-op for a tile that is not placed, which is what we want.
     */
    private fun refresh(id: String) {
        store.componentFor(id)?.let { TileService.requestListeningState(context, it) }
    }

    private fun requestAddTile(id: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("unsupported")
            return
        }
        val component = store.componentFor(id)
        val config = store.config(id)
        if (component == null || config == null) {
            result.error("unknown_control", "No tile slot is bound to \"$id\"", null)
            return
        }
        val statusBar = context.getSystemService(StatusBarManager::class.java)
        val icon = Icon.createWithResource(context, store.iconRes(config.androidIcon))
        statusBar.requestAddTileService(component, config.title, icon, context.mainExecutor) { code ->
            result.success(
                when (code) {
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "notAdded"
                    else -> "failed"
                },
            )
        }
    }
}

package com.jameskrupnik.quick_controls

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.util.UUID

/**
 * One generic tile, bound to whatever control the app declared into its
 * [slot]. The three concrete subclasses exist only because a manifest names
 * classes, not instances.
 *
 * A tap never touches app data. It appends a [PendingEvent], redraws itself
 * with the tap counted in, pings a running engine, and broadcasts
 * [TapBroadcast] to the host for anything else that shows the number. The
 * app applies the event later.
 */
abstract class QuickControlTileService(private val slot: Int) : TileService() {

    private val store by lazy { QuickControlsStore(this) }

    override fun onStartListening() {
        super.onStartListening()
        redraw()
    }

    override fun onTileAdded() {
        super.onTileAdded()
        redraw()
    }

    override fun onClick() {
        super.onClick()
        val config = store.configForSlot(slot) ?: return
        val state = store.state()
        // What the user saw when they tapped. SystemUI delivers a click only
        // to a listening tile, and onStartListening has redrawn it by then.
        // See ControlState.eventForTap for why this beats the store.
        val shownOn = when (qsTile?.state) {
            Tile.STATE_ACTIVE -> true
            Tile.STATE_INACTIVE -> false
            else -> null
        }
        store.events.record { pending ->
            state.eventForTap(config, pending, UUID.randomUUID().toString(), System.currentTimeMillis(), shownOn)
        }
        redraw()
        PingBus.ping(config.id)
        TapBroadcast.of(packageName, config.id).send(this)
        if (config.opensApp) openApp()
    }

    private fun redraw() {
        val tile = qsTile ?: return
        val config = store.configForSlot(slot)
        if (config == null) {
            // A slot enabled by a previous launch whose control is gone; the
            // next initialize() disables it. Until then, look inert.
            tile.state = Tile.STATE_UNAVAILABLE
            tile.updateTile()
            return
        }
        val display = TileDisplay.of(
            config,
            store.state(),
            store.events.peek(),
            hasSubtitle = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q,
        )
        tile.label = display.label
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = display.subtitle
        tile.state = if (display.active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.icon = Icon.createWithResource(this, store.iconRes(config))
        tile.updateTile()
    }

    /**
     * Opens the app and collapses the shade.
     *
     * Android 14 removed the `Intent` overload of `startActivityAndCollapse`
     * for apps targeting it — it throws `UnsupportedOperationException` — and
     * added a `PendingIntent` one. Both are needed, split at API 34.
     * `unlockAndRun` first, because on a locked device the activity would
     * otherwise open behind the keyguard.
     */
    private fun openApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val start = Runnable {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        slot,
                        launch,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(launch)
            }
        }
        if (isLocked) unlockAndRun(start) else start.run()
    }
}

class QuickControlTile0 : QuickControlTileService(0)

class QuickControlTile1 : QuickControlTileService(1)

class QuickControlTile2 : QuickControlTileService(2)

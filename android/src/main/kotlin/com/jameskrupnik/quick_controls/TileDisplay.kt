package com.jameskrupnik.quick_controls

/**
 * What a tile shows, worked out from the app's last published value plus the
 * taps it has not applied yet.
 *
 * Kept free of Android types so the arithmetic is unit tested; the tile
 * service only copies these fields onto a `Tile`.
 */
data class TileDisplay(val label: String, val subtitle: String?, val active: Boolean) {
    companion object {
        /**
         * [hasSubtitle] is false below Android 10, where a tile has only a
         * label, so a counter's number goes on the label instead.
         */
        fun of(
            config: ControlConfig,
            state: ControlState,
            pending: List<PendingEvent>,
            hasSubtitle: Boolean,
        ): TileDisplay = when (config.kind) {
            ControlKind.COUNTER -> {
                val count = state.currentCount(config.id, pending)
                if (hasSubtitle) {
                    TileDisplay(config.title, count.toString(), active = true)
                } else {
                    TileDisplay("${config.title} $count", null, active = true)
                }
            }
            ControlKind.TOGGLE ->
                TileDisplay(config.title, null, active = state.currentIsOn(config.id, pending))
            ControlKind.BUTTON -> TileDisplay(config.title, null, active = false)
        }
    }
}

/** The baselines the app published with `setValue` and `setToggled`. */
data class ControlState(val values: Map<String, Long>, val toggles: Map<String, Boolean>) {
    fun currentCount(id: String, pending: List<PendingEvent>): Long =
        (values[id] ?: 0L) + pending.filter { it.controlId == id && it.kind == ControlKind.COUNTER }
            .sumOf { it.delta }

    /** The newest pending toggle wins over the baseline: it is newer than anything the app saw. */
    fun currentIsOn(id: String, pending: List<PendingEvent>): Boolean =
        pending.lastOrNull { it.controlId == id && it.kind == ControlKind.TOGGLE }?.isOn
            ?: toggles[id] ?: false

    /** The event one tap records, given what the tile was showing when tapped. */
    fun eventForTap(config: ControlConfig, pending: List<PendingEvent>, id: String, now: Long) =
        when (config.kind) {
            ControlKind.COUNTER -> PendingEvent(id, config.id, config.kind, now, delta = config.step)
            ControlKind.TOGGLE ->
                PendingEvent(id, config.id, config.kind, now, isOn = !currentIsOn(config.id, pending))
            ControlKind.BUTTON -> PendingEvent(id, config.id, config.kind, now)
        }
}

package com.jameskrupnik.quick_controls

/**
 * The icon a tile shows when the control has no `androidIcon` of its own.
 *
 * One per kind, not one for all: in the compact tile layout Android hides the
 * label, so tiles that share an icon cannot be told apart. They match the iOS
 * defaults — `plus.circle`, `power`, `hand.tap`.
 */
object TileIcons {
    fun defaultFor(kind: ControlKind): Int = when (kind) {
        ControlKind.COUNTER -> R.drawable.quick_controls_tile_default
        ControlKind.TOGGLE -> R.drawable.quick_controls_tile_toggle
        ControlKind.BUTTON -> R.drawable.quick_controls_tile_button
    }
}

package com.jameskrupnik.quick_controls

import kotlin.test.Test
import kotlin.test.assertEquals

internal class TileIconsTest {
    @Test
    fun eachKind_hasItsOwnDefaultIcon() {
        // In the compact tile layout the label is hidden, so with one shared
        // icon two tiles of different kinds looked identical.
        val icons = ControlKind.entries.map(TileIcons::defaultFor)
        assertEquals(ControlKind.entries.size, icons.toSet().size)
    }

    @Test
    fun theCounter_keepsThePlusInACircle() {
        assertEquals(R.drawable.quick_controls_tile_default, TileIcons.defaultFor(ControlKind.COUNTER))
    }
}

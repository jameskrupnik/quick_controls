package com.jameskrupnik.quick_controls

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

internal class SlotAllocatorTest {
    @Test
    fun freshIds_takeSlotsInOrder() {
        assertEquals(mapOf("a" to 0, "b" to 1), SlotAllocator.allocate(emptyMap(), listOf("a", "b"), 3))
    }

    @Test
    fun anExistingBinding_survivesReordering() {
        val previous = mapOf("rows" to 0, "stitches" to 1)
        val next = SlotAllocator.allocate(previous, listOf("stitches", "rows"), 3)
        assertEquals(previous, next)
    }

    /**
     * A tile the user placed for `old` is slot 0. Handing slot 0 straight to
     * `new` would turn that placed tile into a different control without the
     * user doing anything, which is the harm slot stability exists to stop.
     * An unused slot goes first; the dropped one is disabled and its tile
     * leaves Quick Settings.
     */
    @Test
    fun aNewControl_prefersASlotNobodyHeld_overOneJustDropped() {
        val next = SlotAllocator.allocate(mapOf("old" to 0, "keep" to 1), listOf("keep", "new"), 3)
        assertEquals(mapOf("keep" to 1, "new" to 2), next)
    }

    @Test
    fun aDroppedControl_freesItsSlot_whenNoOtherIsLeft() {
        val next = SlotAllocator.allocate(
            mapOf("old" to 0, "a" to 1, "b" to 2),
            listOf("a", "b", "new"),
            3,
        )
        assertEquals(mapOf("a" to 1, "b" to 2, "new" to 0), next)
    }

    @Test
    fun aSlotBeyondThePool_isReassigned() {
        val next = SlotAllocator.allocate(mapOf("a" to 7), listOf("a"), 3)
        assertEquals(mapOf("a" to 0), next)
    }

    @Test
    fun moreControlsThanSlots_throws() {
        assertFailsWith<TooManyControlsException> {
            SlotAllocator.allocate(emptyMap(), listOf("a", "b", "c", "d"), 3)
        }
    }
}

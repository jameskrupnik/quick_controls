package com.illuminationdevelopment.quick_controls

/** Thrown when more controls are declared than the manifest has tile slots. */
class TooManyControlsException(declared: Int, slots: Int) :
    IllegalArgumentException("$declared controls declared, but only $slots tile slots exist")

/**
 * Binds control ids to tile slots, keeping every binding that still applies.
 *
 * Stability is the point. A tile the user placed in Quick Settings is a
 * *slot*, not a control; if `rows` moved from slot 0 to slot 1 because the
 * app declared its controls in a different order, the tile the user placed
 * would start showing some other control.
 */
object SlotAllocator {
    fun allocate(previous: Map<String, Int>, ids: List<String>, slotCount: Int): Map<String, Int> {
        if (ids.size > slotCount) throw TooManyControlsException(ids.size, slotCount)
        val kept = previous.filter { (id, slot) -> id in ids && slot in 0 until slotCount }
        // Slots no control held last launch first. A slot whose control was
        // just dropped may still be a tile the user placed; given to a new
        // control it would turn into that control in their Quick Settings.
        // Left free, it is disabled and the tile goes. Reused only when
        // there is nothing else.
        val (fresh, dropped) = (0 until slotCount)
            .filter { it !in kept.values }
            .partition { it !in previous.values }
        val free = ArrayDeque(fresh + dropped)
        val result = kept.toMutableMap()
        for (id in ids) {
            if (id !in result) result[id] = free.removeFirst()
        }
        return result
    }
}

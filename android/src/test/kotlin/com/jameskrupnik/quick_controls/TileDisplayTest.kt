package com.jameskrupnik.quick_controls

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class TileDisplayTest {
    private val rows = ControlConfig("rows", ControlKind.COUNTER, "Row", null, 1, false)
    private val light = ControlConfig("light", ControlKind.TOGGLE, "Light", null, 0, false)
    private val go = ControlConfig("go", ControlKind.BUTTON, "Go", null, 0, true)

    private fun plusOne(at: Long, id: String = "rows") =
        PendingEvent("e$at", id, ControlKind.COUNTER, at, delta = 1)

    @Test
    fun counter_showsBasePlusPending() {
        val state = ControlState(mapOf("rows" to 40L), emptyMap())
        val pending = listOf(plusOne(1), plusOne(2), plusOne(3, "other"))
        assertEquals(TileDisplay("Row", "42", true), TileDisplay.of(rows, state, pending, hasSubtitle = true))
    }

    @Test
    fun counter_withoutSubtitles_putsTheNumberOnTheLabel() {
        val state = ControlState(mapOf("rows" to 7L), emptyMap())
        assertEquals("Row 7", TileDisplay.of(rows, state, emptyList(), hasSubtitle = false).label)
    }

    @Test
    fun toggle_pendingTapBeatsTheBaseline() {
        val state = ControlState(emptyMap(), mapOf("light" to true))
        val off = PendingEvent("t", "light", ControlKind.TOGGLE, 1, isOn = false)
        assertEquals(false, TileDisplay.of(light, state, listOf(off), hasSubtitle = true).active)
        assertEquals(true, TileDisplay.of(light, state, emptyList(), hasSubtitle = true).active)
    }

    @Test
    fun tap_onAToggle_recordsTheOppositeOfWhatIsShown() {
        val state = ControlState(emptyMap(), mapOf("light" to true))
        assertEquals(false, state.eventForTap(light, emptyList(), "x", 1).isOn)
        val off = PendingEvent("t", "light", ControlKind.TOGGLE, 1, isOn = false)
        assertEquals(true, state.eventForTap(light, listOf(off), "x", 2).isOn)
    }

    @Test
    fun tap_onACounter_recordsItsStep() {
        val stepThree = rows.copy(step = 3)
        assertEquals(3L, ControlState(emptyMap(), emptyMap()).eventForTap(stepThree, emptyList(), "x", 1).delta)
    }

    @Test
    fun button_hasNoValue() {
        val event = ControlState(emptyMap(), emptyMap()).eventForTap(go, emptyList(), "x", 1)
        assertEquals(0L, event.delta)
        assertNull(event.isOn)
    }

    @Test
    fun config_roundTripsThroughJson() {
        val withIcon = rows.copy(androidIcon = "ic_row", opensApp = true)
        assertEquals(withIcon, ControlConfig.fromJson(withIcon.toJson()))
        assertEquals(go, ControlConfig.fromJson(go.toJson()))
        assertNull(ControlConfig.fromJson("{}"))
    }

    @Test
    fun config_readsTheDartMap() {
        val raw = mapOf(
            "id" to "rows", "kind" to "counter", "title" to "Row",
            "iosSymbol" to "plus", "androidIcon" to null, "step" to 1, "opensApp" to false,
        )
        assertEquals(rows, ControlConfig.fromChannel(raw))
        assertNull(ControlConfig.fromChannel(raw + ("kind" to "slider")))
    }
}

package com.illuminationdevelopment.quick_controls

import kotlin.test.Test
import kotlin.test.assertEquals

internal class TapBroadcastTest {
    @Test
    fun of_isScopedToTheHostPackage_andNamesTheControl() {
        // Without the package the broadcast is implicit: any app could hear
        // it, and Android 8+ would not deliver it to a manifest receiver.
        assertEquals(
            TapBroadcast(
                "com.illuminationdevelopment.quick_controls.action.TAP_RECORDED",
                "com.example.host",
                "row",
            ),
            TapBroadcast.of("com.example.host", "row"),
        )
    }

    @Test
    fun action_isNamespacedToThePlugin() {
        // Hosts declare this string in their manifests; changing it silently
        // stops every host's receiver.
        assertEquals(
            "com.illuminationdevelopment.quick_controls.action.TAP_RECORDED",
            TapBroadcast.ACTION,
        )
        assertEquals("controlId", TapBroadcast.EXTRA_CONTROL_ID)
    }
}

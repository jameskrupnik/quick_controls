package com.jameskrupnik.quick_controls

import android.app.StatusBarManager
import kotlin.test.Test
import kotlin.test.assertEquals

internal class TileAddResultTest {
    @Test
    fun theDocumentedAnswers_mapOneToOne() {
        assertEquals("added", tileAddResultName(StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED))
        assertEquals("alreadyAdded", tileAddResultName(StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED))
        assertEquals("notAdded", tileAddResultName(StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED))
    }

    @Test
    fun aDismissedDialog_isTheUserDeclining_notAFailure() {
        // TILE_ADD_REQUEST_RESULT_DIALOG_DISMISSED, @hide in the SDK, so by
        // value. RequestResultCallback hands it to the app unchanged.
        assertEquals("notAdded", tileAddResultName(3))
    }

    @Test
    fun theErrorCodes_areFailures() {
        (1000..1005).forEach { assertEquals("failed", tileAddResultName(it)) }
        assertEquals("failed", tileAddResultName(-1))
    }
}

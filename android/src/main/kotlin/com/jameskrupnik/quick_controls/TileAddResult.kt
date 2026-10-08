package com.jameskrupnik.quick_controls

import android.app.StatusBarManager

/**
 * `TILE_ADD_REQUEST_RESULT_DIALOG_DISMISSED`: the dialog went away without a
 * choice (back, a tap outside it). `@hide` in the SDK, but
 * `StatusBarManager.RequestResultCallback` passes it to the app unchanged.
 */
private const val DIALOG_DISMISSED = 3

/**
 * The Dart `QuickTileAddResult` name for a `requestAddTileService` code.
 *
 * A dismissed dialog is the user not adding the tile, so `notAdded`; only the
 * `TILE_ADD_REQUEST_ERROR_*` codes (1000 and up) and anything unknown are
 * `failed`, which Dart documents as "the system refused".
 */
fun tileAddResultName(code: Int): String = when (code) {
    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED, DIALOG_DISMISSED -> "notAdded"
    else -> "failed"
}

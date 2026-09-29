package com.illuminationdevelopment.quick_controls

import org.json.JSONArray
import org.json.JSONException

/**
 * The append-only list of taps the app has not applied yet.
 *
 * ### Why a tap cannot be lost to a racing drain
 *
 * Every read-modify-write of the list — [append] from a tile, [drain] from
 * the plugin — holds [LOCK] from the read to the committed write. [LOCK] is
 * one object per *process*, not per instance, because the tile service and
 * the plugin each build their own log over the same file.
 *
 * One process is guaranteed because the manifest declares the tile services
 * without `android:process`, so they run where the Flutter engine runs. A
 * host app that moved them to another process would need a file lock
 * instead; nothing in this package does that.
 *
 * So a tap either commits before a drain reads (and is in that drain's
 * result) or after it wrote (and is in the next). There is no interleaving
 * where the drain's write erases it.
 */
class PendingEventLog(private val store: KeyValueStore) {

    fun append(event: PendingEvent) {
        record { event }
    }

    /**
     * Appends the event [make] builds from what is pending *at that moment*,
     * under the lock. A toggle needs this: it records the opposite of what it
     * shows, and what it shows depends on the pending list, so reading the
     * list and appending must be one step or two quick taps record the same
     * state.
     */
    fun record(make: (pending: List<PendingEvent>) -> PendingEvent): PendingEvent =
        synchronized(LOCK) {
            val events = readLocked()
            val event = make(events)
            events.add(event)
            store.write(mapOf(KEY to encode(events)))
            event
        }

    /** Returns every pending tap and empties the log in one step. */
    fun drain(): List<PendingEvent> = synchronized(LOCK) {
        val events = readLocked()
        if (events.isNotEmpty()) store.write(mapOf(KEY to null))
        events
    }

    /** What is pending, without removing it — for a tile drawing its count. */
    fun peek(): List<PendingEvent> = synchronized(LOCK) { readLocked() }

    private fun readLocked(): MutableList<PendingEvent> {
        val json = store.read(KEY) ?: return mutableListOf()
        val array = try {
            JSONArray(json)
        } catch (e: JSONException) {
            // Unreadable as a whole is not recoverable, and refusing to append
            // would lose every future tap as well. Start over.
            return mutableListOf()
        }
        return (0 until array.length())
            .mapNotNull { array.optJSONObject(it)?.let(PendingEvent::fromJson) }
            .toMutableList()
    }

    private fun encode(events: List<PendingEvent>): String =
        JSONArray().apply { events.forEach { put(it.toJson()) } }.toString()

    companion object {
        const val KEY = "events"

        /** Process-wide. See the class comment for why it is not per instance. */
        private val LOCK = Any()
    }
}

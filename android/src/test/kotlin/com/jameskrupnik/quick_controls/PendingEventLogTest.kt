package com.jameskrupnik.quick_controls

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** A map standing in for SharedPreferences. */
private class MapStore : KeyValueStore {
    val map = ConcurrentHashMap<String, String>()

    override fun read(key: String): String? = map[key]

    override fun write(entries: Map<String, String?>) {
        entries.forEach { (k, v) -> if (v == null) map.remove(k) else map[k] = v }
    }
}

internal class PendingEventLogTest {
    private fun tap(n: Int) = PendingEvent("e$n", "rows", ControlKind.COUNTER, n.toLong(), delta = 1)

    @Test
    fun drain_returnsInOrderAndEmpties() {
        val log = PendingEventLog(MapStore())
        log.append(tap(1))
        log.append(tap(2))
        assertEquals(listOf("e1", "e2"), log.drain().map { it.id })
        assertTrue(log.drain().isEmpty())
    }

    @Test
    fun events_roundTripEveryField() {
        val log = PendingEventLog(MapStore())
        val toggle = PendingEvent("t", "light", ControlKind.TOGGLE, 5L, isOn = true)
        log.append(toggle)
        log.append(tap(1))
        assertEquals(listOf(toggle, tap(1)), log.drain())
    }

    @Test
    fun corruptStorage_isDiscardedRatherThanBlockingNewTaps() {
        val store = MapStore().apply { map[PendingEventLog.KEY] = "not json" }
        val log = PendingEventLog(store)
        log.append(tap(1))
        assertEquals(1, log.drain().size)
    }

    @Test
    fun oneBadEntry_doesNotSinkTheRest() {
        val store = MapStore().apply {
            map[PendingEventLog.KEY] =
                """[{"id":"a","controlId":"rows","kind":"counter","recordedAt":1,"delta":1},""" +
                """{"id":"b","kind":"nope"}]"""
        }
        assertEquals(listOf("a"), PendingEventLog(store).drain().map { it.id })
    }

    /**
     * The guarantee the package is built on: taps racing drains, from two
     * log instances over one store (as the tile and plugin are), lose none
     * and double none.
     */
    @Test
    fun racingTapsAndDrains_deliverEveryTapExactlyOnce() {
        val store = MapStore()
        val tile = PendingEventLog(store)
        val plugin = PendingEventLog(store)
        val tappers = 4
        val tapsEach = 250
        val start = CountDownLatch(1)
        val drained = ConcurrentHashMap.newKeySet<String>()
        val duplicates = AtomicInteger()
        val tapping = AtomicInteger(tappers)

        val threads = (0 until tappers).map { t ->
            thread {
                start.await()
                repeat(tapsEach) { tile.append(tap(t * tapsEach + it)) }
                tapping.decrementAndGet()
            }
        } + thread {
            start.await()
            while (tapping.get() > 0) {
                plugin.drain().forEach { if (!drained.add(it.id)) duplicates.incrementAndGet() }
            }
        }
        start.countDown()
        threads.forEach { it.join() }
        plugin.drain().forEach { if (!drained.add(it.id)) duplicates.incrementAndGet() }

        assertEquals(0, duplicates.get())
        assertEquals(tappers * tapsEach, drained.size)
    }
}

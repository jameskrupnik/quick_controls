package com.jameskrupnik.quick_controls

import io.flutter.plugin.common.EventChannel
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertSame
import org.mockito.Mockito.mock

internal class PingBusTest {
    private val appEngine = Any()
    private val backgroundEngine = Any()

    @AfterTest
    fun reset() {
        PingBus.release(appEngine)
        PingBus.release(backgroundEngine)
    }

    /**
     * A background engine (a push handler's isolate, say) attaches its own
     * plugin instance and later detaches. That must not cut the app's engine
     * off from tile pings.
     */
    @Test
    fun anotherEngineDetaching_keepsTheListenersSink() {
        val sink = mock(EventChannel.EventSink::class.java)
        PingBus.listen(appEngine, sink)

        PingBus.release(backgroundEngine)

        assertSame(sink, PingBus.sink)
    }

    @Test
    fun theListenerReleasing_clearsTheSink() {
        PingBus.listen(appEngine, mock(EventChannel.EventSink::class.java))
        PingBus.release(appEngine)
        assertNull(PingBus.sink)
    }
}

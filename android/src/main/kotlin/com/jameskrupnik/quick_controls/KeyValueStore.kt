package com.jameskrupnik.quick_controls

/**
 * The slice of SharedPreferences the logic needs, so that logic runs in a
 * plain JVM unit test against a map.
 *
 * [write] must be durable when it returns — `commit()`, not `apply()`. A tap
 * recorded with `apply()` can be lost if the process dies in the next few
 * milliseconds, and a tile's process is killed freely once it stops
 * listening.
 */
interface KeyValueStore {
    fun read(key: String): String?

    /** Writes every entry in one commit; a `null` value removes the key. */
    fun write(entries: Map<String, String?>)
}

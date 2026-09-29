package com.illuminationdevelopment.quick_controls

import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import org.json.JSONObject

/**
 * Everything the plugin and the tiles share, in one SharedPreferences file.
 *
 * Its own file, not Flutter's `FlutterSharedPreferences`, so an app calling
 * `SharedPreferences.clear()` from Dart cannot wipe pending taps, and so the
 * keys here are nobody else's business.
 *
 * Writers, by key:
 *  - `slots`, `config.*`, `value.*`, `toggled.*` — the plugin only.
 *  - `events` — tiles append, the plugin drains, both under
 *    [PendingEventLog]'s lock.
 */
class QuickControlsStore(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    val events = PendingEventLog(object : KeyValueStore {
        override fun read(key: String): String? = prefs.getString(key, null)

        override fun write(entries: Map<String, String?>) {
            val editor = prefs.edit()
            entries.forEach { (k, v) -> if (v == null) editor.remove(k) else editor.putString(k, v) }
            // commit, not apply: see KeyValueStore.
            editor.commit()
        }
    })

    /**
     * Stores [controls], binds each to a slot, and enables exactly the slots
     * in use. Throws [TooManyControlsException] before changing anything.
     */
    fun declare(controls: List<ControlConfig>) {
        val slots = SlotAllocator.allocate(slots(), controls.map { it.id }, SLOT_CLASSES.size)
        val editor = prefs.edit()
        prefs.all.keys.filter { it.startsWith(CONFIG) }.forEach { editor.remove(it) }
        controls.forEach { editor.putString(CONFIG + it.id, it.toJson()) }
        editor.putString(SLOTS, JSONObject(slots.mapValues { it.value }).toString())
        editor.commit()

        val used = slots.values.toSet()
        SLOT_CLASSES.indices.forEach { setSlotEnabled(it, it in used) }
    }

    fun slots(): Map<String, Int> {
        val json = prefs.getString(SLOTS, null) ?: return emptyMap()
        return try {
            val o = JSONObject(json)
            o.keys().asSequence().associateWith { o.getInt(it) }
        } catch (e: org.json.JSONException) {
            emptyMap()
        }
    }

    fun config(id: String): ControlConfig? = ControlConfig.fromJson(prefs.getString(CONFIG + id, null))

    fun configForSlot(slot: Int): ControlConfig? =
        slots().entries.firstOrNull { it.value == slot }?.key?.let(::config)

    fun state(): ControlState {
        val all = prefs.all
        return ControlState(
            values = all.filterKeys { it.startsWith(VALUE) }
                .mapNotNull { (k, v) -> (v as? Long)?.let { k.removePrefix(VALUE) to it } }.toMap(),
            toggles = all.filterKeys { it.startsWith(TOGGLED) }
                .mapNotNull { (k, v) -> (v as? Boolean)?.let { k.removePrefix(TOGGLED) to it } }.toMap(),
        )
    }

    fun setValue(id: String, value: Long) {
        prefs.edit().putLong(VALUE + id, value).commit()
    }

    fun setToggled(id: String, isOn: Boolean) {
        prefs.edit().putBoolean(TOGGLED + id, isOn).commit()
    }

    /** The host app's drawable named [name], or the plugin's fallback. */
    fun iconRes(name: String?): Int {
        if (name != null) {
            // The name comes from Dart, so there is no R field to reference.
            @Suppress("DiscouragedApi")
            val id = appContext.resources.getIdentifier(name, "drawable", appContext.packageName)
            if (id != 0) return id
        }
        return R.drawable.quick_controls_tile_default
    }

    fun component(slot: Int) = ComponentName(appContext.packageName, SLOT_CLASSES[slot])

    fun componentFor(id: String): ComponentName? = slots()[id]?.let(::component)

    /**
     * Enables or disables one slot, and only if that changes anything: every
     * change broadcasts `PACKAGE_CHANGED` and makes SystemUI rescan tiles.
     *
     * `DONT_KILL_APP` is load-bearing. Without it, changing a component's
     * state kills the process that asked — the running app.
     */
    private fun setSlotEnabled(slot: Int, enabled: Boolean) {
        val pm = appContext.packageManager
        val wanted = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        val component = component(slot)
        if (pm.getComponentEnabledSetting(component) == wanted) return
        pm.setComponentEnabledSetting(component, wanted, PackageManager.DONT_KILL_APP)
    }

    companion object {
        const val FILE = "com.illuminationdevelopment.quick_controls"
        private const val SLOTS = "slots"
        private const val CONFIG = "config."
        private const val VALUE = "value."
        private const val TOGGLED = "toggled."

        /**
         * The tile pool, by class name rather than `::class.java` so that
         * nothing here needs to load a `TileService` subclass to name it.
         * Must list the same classes, in the same order, as the manifest.
         */
        val SLOT_CLASSES = listOf(
            "com.illuminationdevelopment.quick_controls.QuickControlTile0",
            "com.illuminationdevelopment.quick_controls.QuickControlTile1",
            "com.illuminationdevelopment.quick_controls.QuickControlTile2",
        )
    }
}

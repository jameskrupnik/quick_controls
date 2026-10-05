package com.jameskrupnik.quick_controls

import org.json.JSONObject

/** Mirrors Dart's `QuickControlKind`, matched by [wireName], never by ordinal. */
enum class ControlKind(val wireName: String) {
    BUTTON("button"),
    TOGGLE("toggle"),
    COUNTER("counter");

    companion object {
        fun named(name: Any?): ControlKind? = entries.firstOrNull { it.wireName == name }
    }
}

/**
 * One control as Dart declared it, persisted so a tile can draw itself when
 * the app is not running — which is most of the time a tile is looked at.
 */
data class ControlConfig(
    val id: String,
    val kind: ControlKind,
    val title: String,
    val androidIcon: String?,
    val step: Long,
    val opensApp: Boolean,
) {
    fun toJson(): String = JSONObject()
        .put("id", id)
        .put("kind", kind.wireName)
        .put("title", title)
        .put("androidIcon", androidIcon ?: JSONObject.NULL)
        .put("step", step)
        .put("opensApp", opensApp)
        .toString()

    companion object {
        /** From the map Dart's `QuickControl.toMap` sends; `null` if it is not one. */
        fun fromChannel(raw: Any?): ControlConfig? {
            val map = raw as? Map<*, *> ?: return null
            return ControlConfig(
                id = map["id"] as? String ?: return null,
                kind = ControlKind.named(map["kind"]) ?: return null,
                title = map["title"] as? String ?: return null,
                androidIcon = map["androidIcon"] as? String,
                step = (map["step"] as? Number)?.toLong() ?: 0L,
                opensApp = map["opensApp"] as? Boolean ?: false,
            )
        }

        /** From what [toJson] wrote; `null` for anything unreadable. */
        fun fromJson(json: String?): ControlConfig? {
            if (json == null) return null
            return try {
                val o = JSONObject(json)
                ControlConfig(
                    id = o.getString("id"),
                    kind = ControlKind.named(o.getString("kind")) ?: return null,
                    title = o.getString("title"),
                    androidIcon = if (o.isNull("androidIcon")) null else o.getString("androidIcon"),
                    step = o.optLong("step", 0L),
                    opensApp = o.optBoolean("opensApp", false),
                )
            } catch (e: org.json.JSONException) {
                null
            }
        }
    }
}

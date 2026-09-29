package com.illuminationdevelopment.quick_controls

import org.json.JSONObject

/**
 * One recorded tap. The [id] is minted at the tap, so the app can make
 * applying a batch idempotent if its own save can fail halfway.
 *
 * The field names are the contract with Dart's `QuickControlEvent.tryParse`
 * and with the iOS kit's `QuickControlsStore`; the three must agree.
 */
data class PendingEvent(
    val id: String,
    val controlId: String,
    val kind: ControlKind,
    val recordedAt: Long,
    val delta: Long = 0L,
    val isOn: Boolean? = null,
) {
    fun toChannel(): Map<String, Any?> = mapOf(
        "id" to id,
        "controlId" to controlId,
        "kind" to kind.wireName,
        "recordedAt" to recordedAt,
        "delta" to delta,
        "isOn" to isOn,
    )

    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("controlId", controlId)
        .put("kind", kind.wireName)
        .put("recordedAt", recordedAt)
        .put("delta", delta)
        .put("isOn", isOn ?: JSONObject.NULL)

    companion object {
        fun fromJson(o: JSONObject): PendingEvent? = try {
            PendingEvent(
                id = o.getString("id"),
                controlId = o.getString("controlId"),
                kind = ControlKind.named(o.getString("kind")) ?: return null,
                recordedAt = o.getLong("recordedAt"),
                delta = o.optLong("delta", 0L),
                isOn = if (o.isNull("isOn")) null else o.getBoolean("isOn"),
            )
        } catch (e: org.json.JSONException) {
            null
        }
    }
}

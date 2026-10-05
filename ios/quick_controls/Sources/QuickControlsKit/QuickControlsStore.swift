// QuickControlsKit — part of the quick_controls Flutter plugin, v0.1.0.
//
// This file is compiled twice from the same source: into the plugin (the app
// side) and into the host's widget extension. Foundation only, iOS 15, so it
// builds in both. If you copied it into your extension, re-copy it whenever
// you upgrade quick_controls: the key layout below is a contract with the
// plugin's copy, and a stale copy fails silently.

import Foundation

/// The App Group storage the app and its widget extension share.
///
/// ## Why a tap cannot be lost to a racing drain
///
/// Two processes write this store, and `UserDefaults` has no cross-process
/// compare-and-swap, so a shared list (read, append, write back) would lose
/// taps: the extension appends while the app is removing, and whichever
/// writes last erases the other's change. So **there is no shared list.**
///
/// - Every tap is written under a key of its own,
///   `quick_controls.event.<uuid>`, and that key is never written again.
/// - A drain snapshots the event keys it can see, returns them, and removes
///   exactly those keys, one by one.
///
/// A tap that lands mid-drain has a key the snapshot did not contain, so the
/// drain neither returns nor removes it, and the next drain gets it. A key
/// the drain removes is one it already returned. The tap is never lost and
/// never counted twice. The Android half gets the same guarantee a different
/// way, with a lock, because its tile runs in the app's own process.
///
/// Every other key has one writer, the app: `config.*` in `saveControls`,
/// `value.*` and `toggled.*` in `setValue` and `setToggled`.
public struct QuickControlsStore {
    public let appGroupId: String
    let defaults: UserDefaults

    /// `nil` if the suite cannot be opened at all. That is *not* a check that
    /// the App Group is entitled: an unentitled suite opens fine and is
    /// private to the process. [isAppGroupEntitled] is that check.
    public init?(appGroupId: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        self.appGroupId = appGroupId
        self.defaults = defaults
    }

    /// Whether this process can actually share the group. Without the
    /// entitlement every write succeeds and nothing reaches the other side,
    /// which is the single most likely setup mistake.
    public var isAppGroupEntitled: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) != nil
    }

    // MARK: Controls, written by the app

    /// Replaces every control's configuration. Removes configs for ids no
    /// longer declared, so the extension shows its Swift defaults for them.
    public func saveControls(_ controls: [QuickControlConfig]) {
        for key in keys(withPrefix: Key.config) { defaults.removeObject(forKey: key) }
        for control in controls { defaults.set(control.plist, forKey: Key.config + control.id) }
    }

    public func control(_ id: String) -> QuickControlConfig? {
        (defaults.dictionary(forKey: Key.config + id)).flatMap(QuickControlConfig.init(plist:))
    }

    public func setValue(_ value: Int, for id: String) {
        defaults.set(value, forKey: Key.value + id)
    }

    public func setToggled(_ isOn: Bool, for id: String) {
        defaults.set(isOn, forKey: Key.toggled + id)
    }

    // MARK: What a control shows

    /// The last published value plus every tap not yet drained.
    public func currentCount(_ id: String) -> Int {
        defaults.integer(forKey: Key.value + id)
            + pending().filter { $0.controlId == id && $0.kind == .counter }.reduce(0) { $0 + $1.delta }
    }

    /// The newest pending toggle, or the last published state.
    public func currentIsOn(_ id: String) -> Bool {
        let latest = pending()
            .filter { $0.controlId == id && $0.kind == .toggle }
            .max { $0.recordedAt < $1.recordedAt }
        return latest?.isOn ?? defaults.bool(forKey: Key.toggled + id)
    }

    // MARK: Pending events

    /// Records one tap under a key nobody else will ever write. See the type
    /// comment for why this is the whole race-safety argument.
    public func record(_ event: QuickControlPendingEvent) {
        defaults.set(event.plist, forKey: Key.event + event.id)
    }

    /// Records a tap on [id] as the kind its config says, with a fresh id.
    @discardableResult
    public func recordTap(
        on id: String, kind: QuickControlKind, isOn: Bool? = nil, now: Date = Date()
    ) -> QuickControlPendingEvent {
        let event = QuickControlPendingEvent(
            id: UUID().uuidString,
            controlId: id,
            kind: kind,
            recordedAt: Int64((now.timeIntervalSince1970 * 1000).rounded()),
            delta: kind == .counter ? (control(id)?.step ?? 1) : 0,
            isOn: kind == .toggle ? isOn : nil)
        record(event)
        return event
    }

    public func pending() -> [QuickControlPendingEvent] {
        keys(withPrefix: Key.event)
            .compactMap { defaults.dictionary(forKey: $0).flatMap(QuickControlPendingEvent.init(plist:)) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Returns the pending taps and removes exactly those, by key.
    public func drain() -> [QuickControlPendingEvent] {
        var drained: [QuickControlPendingEvent] = []
        for key in keys(withPrefix: Key.event) {
            // Read then remove the same key. A malformed entry is removed too:
            // it would otherwise sit there forever, re-failing every drain.
            if let event = defaults.dictionary(forKey: key).flatMap(QuickControlPendingEvent.init(plist:)) {
                drained.append(event)
            }
            defaults.removeObject(forKey: key)
        }
        return drained.sorted { $0.recordedAt < $1.recordedAt }
    }

    private func keys(withPrefix prefix: String) -> [String] {
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
    }

    // MARK: Cross-process ping

    /// The Darwin notification the extension posts after recording a tap, so
    /// a running app can drain at once. Scoped by group, since Darwin
    /// notifications are system-wide.
    public static func changedNotificationName(appGroupId: String) -> String {
        "com.jameskrupnik.quick_controls.changed." + appGroupId
    }

    public func postChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Self.changedNotificationName(appGroupId: appGroupId) as CFString),
            nil, nil, true)
    }

    enum Key {
        static let config = "quick_controls.config."
        static let value = "quick_controls.value."
        static let toggled = "quick_controls.toggled."
        static let event = "quick_controls.event."
    }
}

/// Mirrors Dart's `QuickControlKind`, matched by raw value.
public enum QuickControlKind: String {
    case button, toggle, counter
}

/// What the app declared for one control, as the extension needs it.
public struct QuickControlConfig: Equatable {
    public let id: String
    public let kind: QuickControlKind
    public let title: String
    public let symbol: String
    public let step: Int

    public init(id: String, kind: QuickControlKind, title: String, symbol: String, step: Int) {
        self.id = id
        self.kind = kind
        self.title = title
        self.symbol = symbol
        self.step = step
    }

    /// From Dart's `QuickControl.toMap`. Only the fields iOS uses are kept,
    /// which also drops the `NSNull`s a property list cannot hold.
    public init?(plist: [String: Any]) {
        guard let id = plist["id"] as? String,
            let kind = (plist["kind"] as? String).flatMap(QuickControlKind.init(rawValue:)),
            let title = plist["title"] as? String
        else { return nil }
        self.init(
            id: id, kind: kind, title: title,
            symbol: plist["iosSymbol"] as? String ?? "circle",
            step: (plist["step"] as? NSNumber)?.intValue ?? 1)
    }

    var plist: [String: Any] {
        ["id": id, "kind": kind.rawValue, "title": title, "iosSymbol": symbol, "step": step]
    }
}

/// One recorded tap. Field names are the contract with Dart's
/// `QuickControlEvent.tryParse` and Kotlin's `PendingEvent`.
public struct QuickControlPendingEvent: Equatable {
    public let id: String
    public let controlId: String
    public let kind: QuickControlKind
    /// Milliseconds since 1970, as Dart's `DateTime.fromMillisecondsSinceEpoch` reads it.
    public let recordedAt: Int64
    public let delta: Int
    public let isOn: Bool?

    public init(
        id: String, controlId: String, kind: QuickControlKind, recordedAt: Int64, delta: Int,
        isOn: Bool?
    ) {
        self.id = id
        self.controlId = controlId
        self.kind = kind
        self.recordedAt = recordedAt
        self.delta = delta
        self.isOn = isOn
    }

    init?(plist: [String: Any]) {
        guard let id = plist["id"] as? String,
            let controlId = plist["controlId"] as? String,
            let kind = (plist["kind"] as? String).flatMap(QuickControlKind.init(rawValue:)),
            let recordedAt = (plist["recordedAt"] as? NSNumber)?.int64Value
        else { return nil }
        self.init(
            id: id, controlId: controlId, kind: kind, recordedAt: recordedAt,
            delta: (plist["delta"] as? NSNumber)?.intValue ?? 0,
            isOn: plist["isOn"] as? Bool)
    }

    /// Also the shape handed to Dart over the method channel. `isOn` is left
    /// out rather than stored as `NSNull`, which a property list rejects.
    public var plist: [String: Any] {
        var map: [String: Any] = [
            "id": id, "controlId": controlId, "kind": kind.rawValue,
            "recordedAt": NSNumber(value: recordedAt), "delta": delta,
        ]
        if let isOn { map["isOn"] = isOn }
        return map
    }
}

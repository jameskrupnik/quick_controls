// QuickControlsKit — part of the quick_controls Flutter plugin, v0.1.0.
// For the widget extension target only. Not compiled into the plugin.

import AppIntents
import Foundation
import WidgetKit

/// The extension's view of the store. The App Group comes from the
/// `QuickControlsAppGroup` key in the **extension's** Info.plist, because an
/// intent carries only its parameters and the extension has no Dart to ask.
enum QuickControlsExtension {
    static let appGroupInfoKey = "QuickControlsAppGroup"

    static var store: QuickControlsStore? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String
        else { return nil }
        return QuickControlsStore(appGroupId: group)
    }

    /// Records the tap, then tells a running app. The control redraws itself
    /// after its action returns; the explicit reload covers the same control
    /// placed on a second surface (Control Center *and* Lock Screen).
    @available(iOS 18.0, *)
    static func record(_ id: String, kind: QuickControlKind, isOn: Bool? = nil) {
        guard let store else { return }
        store.recordTap(on: id, kind: kind, isOn: isOn)
        store.postChanged()
        ControlCenter.shared.reloadControls(ofKind: id)
    }
}

/// A counter tap: records `+step` and does **not** open the app.
@available(iOS 18.0, *)
public struct QuickCounterTapIntent: AppIntent {
    public static let title: LocalizedStringResource = "Count one"
    // Controls only. Not offered in Shortcuts, where a tap with no visible
    // result would look broken.
    public static let isDiscoverable = false

    @Parameter(title: "Control")
    public var controlId: String

    public init() {}

    public init(controlId: String) {
        self.controlId = controlId
    }

    public func perform() async throws -> some IntentResult {
        QuickControlsExtension.record(controlId, kind: .counter)
        return .result()
    }
}

/// A toggle tap. The system hands over the state being switched *to*, so
/// there is no read-modify-write here to race.
@available(iOS 18.0, *)
public struct QuickToggleSetIntent: SetValueIntent {
    public static let title: LocalizedStringResource = "Switch"
    public static let isDiscoverable = false

    @Parameter(title: "Control")
    public var controlId: String

    @Parameter(title: "On")
    public var value: Bool

    public init() {}

    public init(controlId: String) {
        self.controlId = controlId
    }

    public func perform() async throws -> some IntentResult {
        QuickControlsExtension.record(controlId, kind: .toggle, isOn: value)
        return .result()
    }
}

/// A button tap that stays in the extension.
@available(iOS 18.0, *)
public struct QuickButtonTapIntent: AppIntent {
    public static let title: LocalizedStringResource = "Press"
    public static let isDiscoverable = false

    @Parameter(title: "Control")
    public var controlId: String

    public init() {}

    public init(controlId: String) {
        self.controlId = controlId
    }

    public func perform() async throws -> some IntentResult {
        QuickControlsExtension.record(controlId, kind: .button)
        return .result()
    }
}

/// A button tap that records the tap and then opens [url] — the only kit
/// intent that leaves the extension, and only when a definition asks for it
/// with `openURL`.
///
/// A separate type, not a flag, because `perform()`'s result type is fixed
/// at compile time: "sometimes opens" cannot be one intent.
@available(iOS 18.0, *)
public struct QuickButtonTapAndOpenIntent: AppIntent {
    public static let title: LocalizedStringResource = "Press and open"
    public static let isDiscoverable = false

    @Parameter(title: "Control")
    public var controlId: String

    @Parameter(title: "URL")
    public var url: URL

    public init() {}

    public init(controlId: String, url: URL) {
        self.controlId = controlId
        self.url = url
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        QuickControlsExtension.record(controlId, kind: .button)
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// QuickControlsKit — part of the quick_controls Flutter plugin, v0.1.0.
// For the widget extension target only. Not compiled into the plugin.

import AppIntents
import SwiftUI
import WidgetKit

/// One control, described in Swift for the widget extension.
///
/// A `ControlWidget` must be a type the extension's `WidgetBundle` names at
/// compile time, and must have an `init()` with no arguments, so it cannot be
/// told its id at runtime. A definition type is how a generic control learns
/// it: `QuickCounterControl<RowsControl>()`.
///
/// [controlId] must equal the `id` of the matching `QuickControl` in Dart.
/// [title] and [systemImage] are what the control shows before the app has
/// ever run, and what the controls gallery lists it as; once the app has
/// called `initialize`, the Dart title and `iosSymbol` win.
public protocol QuickControlDefinition {
    static var controlId: String { get }
    static var title: String { get }
    static var systemImage: String { get }
}

/// A definition whose button opens the app, via a URL the app handles —
/// a universal link or the app's own scheme.
public protocol QuickControlOpeningDefinition: QuickControlDefinition {
    static var openURL: URL { get }
}

/// What a control reads from the store each time the system asks.
public struct QuickControlSnapshot {
    public let title: String
    public let symbol: String
    public let count: Int
    public let isOn: Bool

    /// Read now, with pending taps counted in, falling back to [D]'s Swift
    /// defaults when the app has not declared the control yet.
    static func read<D: QuickControlDefinition>(_: D.Type) -> QuickControlSnapshot {
        let store = QuickControlsExtension.store
        let config = store?.control(D.controlId)
        return QuickControlSnapshot(
            title: config?.title ?? D.title,
            symbol: config?.symbol ?? D.systemImage,
            count: store?.currentCount(D.controlId) ?? 0,
            isOn: store?.currentIsOn(D.controlId) ?? false)
    }

    static func placeholder<D: QuickControlDefinition>(_: D.Type) -> QuickControlSnapshot {
        QuickControlSnapshot(title: D.title, symbol: D.systemImage, count: 0, isOn: false)
    }
}

@available(iOS 18.0, *)
public struct QuickControlValueProvider<D: QuickControlDefinition>: ControlValueProvider {
    public init() {}

    public var previewValue: QuickControlSnapshot { .placeholder(D.self) }

    public func currentValue() async throws -> QuickControlSnapshot { .read(D.self) }
}

/// A `+step` button that shows its count: the last value the app published
/// plus every tap not yet drained.
@available(iOS 18.0, *)
public struct QuickCounterControl<D: QuickControlDefinition>: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: D.controlId, provider: QuickControlValueProvider<D>()) { value in
            ControlWidgetButton(action: QuickCounterTapIntent(controlId: D.controlId)) {
                Label("\(value.title) \(value.count)", systemImage: value.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: D.title))
    }
}

/// An on/off switch. What it shows is the newest pending tap, or the last
/// state the app published.
@available(iOS 18.0, *)
public struct QuickToggleControl<D: QuickControlDefinition>: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: D.controlId, provider: QuickControlValueProvider<D>()) { value in
            ControlWidgetToggle(
                value.title,
                isOn: value.isOn,
                action: QuickToggleSetIntent(controlId: D.controlId)
            ) { isOn in
                Label(isOn ? "On" : "Off", systemImage: value.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: D.title))
    }
}

/// A plain button. Records a tap and stays out of the app.
@available(iOS 18.0, *)
public struct QuickButtonControl<D: QuickControlDefinition>: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: D.controlId, provider: QuickControlValueProvider<D>()) { value in
            ControlWidgetButton(action: QuickButtonTapIntent(controlId: D.controlId)) {
                Label(value.title, systemImage: value.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: D.title))
    }
}

/// A button that records a tap and then opens the app at [D.openURL].
@available(iOS 18.0, *)
public struct QuickOpeningButtonControl<D: QuickControlOpeningDefinition>: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: D.controlId, provider: QuickControlValueProvider<D>()) { value in
            ControlWidgetButton(
                action: QuickButtonTapAndOpenIntent(controlId: D.controlId, url: D.openURL)
            ) {
                Label(value.title, systemImage: value.symbol)
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: D.title))
    }
}

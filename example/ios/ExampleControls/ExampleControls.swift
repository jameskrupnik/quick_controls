import SwiftUI
import WidgetKit

// The example's widget extension: three definitions and a bundle, which is
// all a host app writes. Everything else is QuickControlsKit, compiled in
// from ../../ios/quick_controls/Sources/QuickControlsKit by reference, so
// this target proves the kit as shipped compiles.
//
// Each controlId must equal the id of a QuickControl in lib/main.dart.

enum RowsControl: QuickControlDefinition {
    static let controlId = "rows"
    static let title = "Row"
    static let systemImage = "plus.circle"
}

enum LightControl: QuickControlDefinition {
    static let controlId = "light"
    static let title = "Light"
    static let systemImage = "lightbulb"
}

enum PingControl: QuickControlOpeningDefinition {
    static let controlId = "ping"
    static let title = "Ping"
    static let systemImage = "bell"
    // The example registers no URL scheme, so this opens nothing useful. It
    // is here to prove the opening variant compiles; a real app uses a
    // universal link or its own scheme.
    static let openURL = URL(string: "quickcontrolsexample://ping")!
}

/// The extension's deployment target is iOS 17, below controls, on purpose:
/// it proves the kit drops into an extension that already serves older home
/// screen widgets, which is Stitch Keeper's `CounterWidget`.
@main
struct ExampleControlsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            QuickCounterControl<RowsControl>()
            QuickToggleControl<LightControl>()
            QuickOpeningButtonControl<PingControl>()
        }
    }
}

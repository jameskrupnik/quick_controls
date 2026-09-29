// swift-tools-version: 5.9

import PackageDescription

// Two targets, because the store is shared and the rest is not.
//
// `QuickControlsShared` is `QuickControlsStore.swift` alone: Foundation only,
// compiled into the plugin (so the app reads and writes the App Group) and
// also into the host's widget extension, from the same file. The other two
// files in that directory — the ControlWidgets and their AppIntents — are for
// the extension only and are excluded here, so the Runner app never links
// WidgetKit UI or registers intents it cannot run.
//
// iOS 15, not the template's 13: the plugin imports WidgetKit to reach
// `ControlCenter`, and WidgetKit does not exist before iOS 14. The CocoaPods
// build does weak-link it (otool shows `weak`), but a dependency package has
// no supported way to *ask* for that (`unsafeFlags` is refused for them), and
// it was never checked on an iOS 13 device. 15 removes the question.
let package = Package(
    name: "quick_controls",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "quick-controls", targets: ["quick_controls"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "QuickControlsShared",
            path: "Sources/QuickControlsKit",
            exclude: ["QuickControlWidgets.swift", "QuickControlIntents.swift"],
            sources: ["QuickControlsStore.swift"]
        ),
        .target(
            name: "quick_controls",
            dependencies: [
                "QuickControlsShared",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
    ]
)

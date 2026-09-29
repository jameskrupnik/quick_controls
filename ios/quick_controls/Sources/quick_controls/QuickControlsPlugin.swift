import Flutter
import UIKit
import WidgetKit

// Under Swift Package Manager the store is its own module; under CocoaPods it
// is compiled into this one. See Package.swift.
#if canImport(QuickControlsShared)
    import QuickControlsShared
#endif

/// The iOS half of `QuickControls`: reads and writes the App Group the
/// host's widget extension shares, and asks WidgetKit to redraw.
///
/// Controls themselves live in the extension, never here. This side only
/// publishes configuration and baselines, and drains the taps the extension
/// recorded.
public class QuickControlsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var store: QuickControlsStore?
    private var sink: FlutterEventSink?
    private var observing: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = QuickControlsPlugin()
        let methods = FlutterMethodChannel(name: "quick_controls", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        FlutterEventChannel(name: "quick_controls/pings", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isSupported":
            if #available(iOS 18.0, *) { result(true) } else { result(false) }
        case "initialize":
            initialize(args, result: result)
        case "requestAddTile":
            result("unsupported")
        default:
            guard let store else {
                result(FlutterError(code: "not_initialized", message: "Call initialize() first", details: nil))
                return
            }
            handleInitialized(call.method, args, store: store, result: result)
        }
    }

    private func handleInitialized(
        _ method: String, _ args: [String: Any], store: QuickControlsStore, result: @escaping FlutterResult
    ) {
        let id = args["id"] as? String
        switch method {
        case "setValue":
            store.setValue((args["value"] as? NSNumber)?.intValue ?? 0, for: id ?? "")
            reload(id)
            result(nil)
        case "setToggled":
            store.setToggled(args["isOn"] as? Bool ?? false, for: id ?? "")
            reload(id)
            result(nil)
        case "drainPendingEvents":
            result(store.drain().map(\.plist))
        case "reload":
            reload(id)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let group = args["appGroupId"] as? String, let store = QuickControlsStore(appGroupId: group) else {
            result(FlutterError(code: "no_app_group", message: "iosAppGroupId is missing or invalid", details: nil))
            return
        }
        // Without the entitlement every write "works" and the extension sees
        // none of it. Fail loudly instead of shipping a control that never
        // counts.
        guard store.isAppGroupEntitled else {
            result(
                FlutterError(
                    code: "no_app_group",
                    message: "\(group) is not in this app's entitlements. Add the App Group capability to "
                        + "Runner and to the widget extension.",
                    details: nil))
            return
        }
        let controls = (args["controls"] as? [[String: Any]] ?? []).compactMap(QuickControlConfig.init(plist:))
        store.saveControls(controls)
        self.store = store
        observe(group)
        reload(nil)
        result(nil)
    }

    /// Redraws one control, or all of them. A no-op below iOS 18, where there
    /// are no controls to redraw.
    private func reload(_ id: String?) {
        guard #available(iOS 18.0, *) else { return }
        if let id {
            ControlCenter.shared.reloadControls(ofKind: id)
        } else {
            ControlCenter.shared.reloadAllControls()
        }
    }

    // MARK: Live pings

    /// Listens for the extension's Darwin notification. It arrives only while
    /// this process is running and not suspended — which is why the drain on
    /// resume is required, and this is only the fast path.
    private func observe(_ group: String) {
        guard observing != group else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        if let previous = observing {
            CFNotificationCenterRemoveObserver(
                center, observer,
                CFNotificationName(QuickControlsStore.changedNotificationName(appGroupId: previous) as CFString),
                nil)
        }
        observing = group
        CFNotificationCenterAddObserver(
            center, observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let plugin = Unmanaged<QuickControlsPlugin>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { plugin.sink?(["controlId": NSNull()]) }
            },
            QuickControlsStore.changedNotificationName(appGroupId: group) as CFString,
            nil, .deliverImmediately)
    }

    /// The observer is registered with an unretained pointer to `self`, so
    /// it must go before `self` does or a late notification is a crash.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        stopObserving()
        sink = nil
    }

    deinit {
        stopObserving()
    }

    private func stopObserving() {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
        observing = nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}

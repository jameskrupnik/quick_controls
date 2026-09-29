# Changelog

## Unreleased

- Fix: taps a ping's drain took from native just as the last `events`
  listener cancelled were dropped by the broadcast stream, and lost. They are
  now held and returned first by the next `drainPendingEvents()`.
- Fix: a stream drain failing with anything but a `PlatformException` failed
  the drain chain, so no later ping drained again in that process. Every
  error now reaches the stream and the chain carries on.
- Fix (Android): a second Flutter engine in the process (a push handler's
  background isolate, say) cleared the shared ping sink when it detached,
  silencing live taps for the app's engine. The sink now belongs to the
  plugin instance that set it.
- Fix (Android): a new control took the slot of a control dropped the same
  launch, turning a tile the user had placed into a different control. A slot
  no control held last launch now goes first.
- Android: a tile tap now also sends `TapBroadcast.ACTION` to the host's own
  package, so something outside the Flutter engine (a home screen widget) can
  redraw when the app is not running. Found integrating Stitch Keeper, whose
  widget adds the tile's pending taps to its count and had no way to hear one.

## 0.1.0

Initial cut. One Dart API over iOS 18 Control widgets and Android Quick
Settings tiles, built around one rule: a control records a tap and never
changes app state.

- `QuickControl.counter`, `.toggle` and `.button`, declared by id from Dart.
  `setValue`/`setToggled` publish a baseline. `drainPendingEvents()` returns
  and removes the recorded taps, with ids and timestamps. `events` carries
  taps while the app runs, built on the same drain so no tap is delivered
  twice.
- Android: three generic `TileService` slots, disabled in the manifest and
  enabled per control at runtime, so the host manifest is untouched. A slot
  stays bound to its control across launches. A tap appends to a pending log
  under a process-wide lock. `requestAddTile` uses
  `StatusBarManager.requestAddTileService` on API 33+. Opening the app handles
  Android 14's `PendingIntent`-only `startActivityAndCollapse`.
- iOS: `QuickControlsKit`, three Swift files for the host's widget extension.
  It provides generic `ControlWidget`s for each kind plus an opening button,
  and non-discoverable `AppIntent`s that record into the App Group. There is
  one key per tap, so the extension and the app never rewrite each other's
  data. The plugin reloads through `ControlCenter` and hears the extension
  through a Darwin notification.
- Swift Package Manager and CocoaPods both supported. iOS 15 minimum, Android
  `minSdk` 24.

**Everything compiles, including a real widget extension target in the
example, and the logic is tested on three layers: Dart, JVM, and a macOS
cross-process check of the iOS store. None of it has been tapped on a real
Control Center or Quick Settings panel.** See the README's status table.

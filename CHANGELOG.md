# Changelog

## 0.1.0

Initial cut. One Dart API over iOS 18 Control widgets and Android Quick
Settings tiles, built around one rule: a control records a tap and never
changes app state.

- `QuickControl.counter`, `.toggle` and `.button`, declared by id from Dart.
  `setValue`/`setToggled` publish a baseline. `drainPendingEvents()` returns
  and removes the recorded taps, with ids and timestamps. `events` carries
  taps while the app runs, built on the same drain so each tap is delivered
  once. Taps a stream drain takes as the last listener leaves are held for
  the next `drainPendingEvents()`. `drainPendingEvents()` and `reload()`
  throw a `StateError` before `initialize` on both platforms.
- `QuickControlEvent` asserts that only a toggle carries `isOn`, that a
  toggle always does, and that only a counter carries `delta`.
- Android: three generic `TileService` slots, disabled in the manifest and
  enabled per control at runtime, so the host manifest is untouched. A slot
  stays bound to its control across launches. A tap appends to a pending log
  under a process-wide lock, and a toggle tile flips what it shows. Each kind
  has its own default icon; a custom `androidIcon` must be kept from resource
  shrinking (see the README). A tap also sends `TapBroadcast.ACTION` to the
  host package, so a home screen widget can redraw with the app not running.
  `requestAddTile` uses `StatusBarManager.requestAddTileService` on API 33+,
  and a dismissed dialog is `notAdded`. Opening the app handles Android 14's
  `PendingIntent`-only `startActivityAndCollapse`.
- iOS: `QuickControlsKit`, three Swift files for the host's widget extension.
  It provides generic `ControlWidget`s for each kind plus an opening button,
  and non-discoverable `AppIntent`s that record into the App Group. There is
  one key per tap, so the extension and the app never rewrite each other's
  data. The plugin reloads through `ControlCenter` and hears the extension
  through a Darwin notification.
- Swift Package Manager and CocoaPods both supported. iOS 15 minimum, Android
  `minSdk` 24.

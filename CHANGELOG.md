# Changelog

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

Changes made before the first publish, found while integrating it into an app:

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
- API: the native wire format is no longer public. `QuickControl.toMap`,
  `QuickControlEvent.tryParse`/`parseAll` and `QuickTileAddResult.fromName`
  moved out of the exported types, so changing the channel format later is
  not a breaking change.
- Fix (Android): every tile without an `androidIcon` showed the same
  plus-in-a-circle, and the compact tile layout hides the label, so a toggle
  and a counter looked identical. Each kind now has its own default icon: a
  plus in a circle, a power symbol, a tapping hand.
- Fix (Android): a toggle tile tapped after the app drained a toggle tap but
  before it called `setToggled` recorded the state it was already showing,
  because nothing was pending and the baseline was still old. A tap now flips
  what the tile shows.
- Fix (Android): `requestAddTile` answered `failed` when the user dismissed
  the dialog without choosing (back, a tap outside it). That is the user
  declining, so it is now `notAdded`; `failed` is left for the system's error
  codes.
- `QuickControlEvent` asserts that only a toggle carries `isOn`, that a toggle
  always does, and that only a counter carries `delta`. A toggle built without
  a state made `latestToggleFor` answer `null` for a batch that was toggled.
- Docs: an `androidIcon` drawable must be listed in `res/raw/keep.xml`, or
  release resource shrinking strips it and the tile shows the default icon.
  Found by building the example for release.

# quick_controls

One Dart API for **iOS 18 Control widgets** (Control Center, the Lock Screen,
the Action button) and **Android Quick Settings tiles**. Declare a counter, a
toggle or a button once, and it shows up on each platform's native surface
and works without the app opening.

## Why this exists

Nothing on pub.dev covers both surfaces. As of 2026-09:

- `quick_settings` is Android-only and was last published in 2023-05.
- `flutter_control_center` is iOS-only and was created on 2026-09-22.
- `home_widget` handles home screen widgets, not controls.

The first consumer is Stitch Keeper, a row counter used with both hands busy.
It needs "+1 row" from Control Center, the Action button or a Quick Settings
tile, without opening the app.

## The rule this package is built on

**A control never changes app state.** The iOS extension and the Android tile
only *record* a tap, as a pending event with its own id. They redraw
optimistically with the tap counted in. The app applies the events when it
next runs, then publishes the new baseline:

```dart
final events = await QuickControls.instance.drainPendingEvents();
rows += events.deltaFor('row_plus_one');
await save(rows);                                   // your storage
await QuickControls.instance.setValue('row_plus_one', rows);
```

This keeps a single writer for the app's data. That single writer is the
reason a tap and a save that race cannot lose an increment.

## Status: what is proven and what is not

**Everything compiles and every piece of logic is tested. Nothing has been
tapped on a real Control Center or a real Quick Settings panel.**

| Layer | State |
|---|---|
| Dart API, event parsing, exactly-once stream | 43 tests, green |
| Android pending log, slot allocation, tile display maths, tap broadcast, ping sink ownership | 23 JVM unit tests, green, including a 4-thread tap/drain race. **The race test fails if the lock is removed**: checked by removing it |
| Android plugin + 3 `TileService` slots | Installed and tapped in Stitch Keeper on a Pixel Tablet API 35 emulator (2026-09-26) through `cmd statusbar add-tile`/`click-tile`: slot 0 enabled by `initialize`, taps recorded, drained exactly once, subtitle updated, `TapBroadcast` received by a home widget. Not on a real phone; `requestAddTile` still never run |
| iOS plugin, CocoaPods | `flutter build ios --simulator --no-codesign` succeeds |
| iOS plugin, Swift Package Manager | The same build succeeds with SPM on. The `QuickControlsShared` module is linked and the plugin is absent from `Podfile.lock` |
| iOS kit (`QuickControlsKit`) | Compiled inside a **real widget extension target** in `example/ios` (deployment target 17.0, controls behind `#available(iOS 18)`). All four intents are in the extension's extracted App Intents metadata, all non-discoverable. It also typechecks with `swiftc` in Swift 5 and Swift 6 modes |
| iOS store race-safety | `tool/store_race_check.sh`: 4 macOS processes × 1,500 taps against a draining process over one `UserDefaults` suite (cfprefsd). 6,000 drained, 6,000 unique. This is macOS, not iOS |
| A control in Control Center, the Lock Screen or the Action button | **Never seen.** `simctl` cannot add a control or tap one |
| A tile in Quick Settings | Seen and tapped on an emulator only (see above). `requestAddTile`'s dialog and `startActivityAndCollapse` on Android 14: **never run** |
| Darwin-notification pings reaching a running iOS app | **Never run** |
| `OpenURLIntent` from `QuickOpeningButtonControl` actually opening an app | **Never run**. Apple documents it for universal links; a custom scheme is untested |

These are the things most likely to need correcting on first device run:

- **How a counter shows its number on iOS.** It is currently
  `Label("Row 42", …)`. Control Center may lay out a title and a value
  differently from that, and it has not been looked at.
- **Cross-process `UserDefaults` freshness on iOS.** The app reads what the
  extension wrote through cfprefsd. That worked across processes on macOS. On
  iOS, a stale read would *delay* a tap to the next drain, never lose it, but
  that has not been observed either way.
- **Tile label in the Quick Settings editor.** Slots have no manifest label,
  so the editor lists every slot under the app's name until one is placed and
  draws its live label.

## Install

```yaml
dependencies:
  quick_controls:
    path: ../quick_controls   # not published
```

Requires Flutter 3.44 (the only version built against), **iOS 15** and
**Android `minSdk` 24**. The iOS half supports both Swift Package Manager and
CocoaPods.

iOS 15, not the template's 13, because the plugin imports WidgetKit to reach
`ControlCenter`. WidgetKit does not exist before iOS 14. In the CocoaPods
build the linker did weak-link it (`otool -L` shows `weak`), so 13 might work,
but that was not checked under SPM or on an iOS 13 device. 15 removes the
question.

## Use

```dart
await QuickControls.instance.initialize(
  iosAppGroupId: 'group.com.example.app',    // required on iOS
  controls: const [
    QuickControl.counter(id: 'rows', title: 'Row'),
    QuickControl.toggle(id: 'light', title: 'Light', iosSymbol: 'lightbulb'),
    QuickControl.button(id: 'ping', title: 'Ping', androidIcon: 'ic_ping'),
  ],
);

// On launch and on every resume:
final events = await QuickControls.instance.drainPendingEvents();

// Optional, while the app is open:
QuickControls.instance.events.listen((event) { /* apply one */ });

await QuickControls.instance.setValue('rows', 42);
await QuickControls.instance.setToggled('light', isOn: true);
await QuickControls.instance.reload();
final result = await QuickControls.instance.requestAddTile('rows'); // Android 13+
final ok = await QuickControls.instance.isSupported();      // iOS 18+ / API 24+
```

The API, briefly:

| Member | What it does |
|---|---|
| `initialize({controls, iosAppGroupId})` | Declares the full list every launch. Validates ids (letters, digits, `_ - .`), rejects duplicates |
| `setValue(id, int)` / `setToggled(id, isOn:)` | Publishes the baseline. Rejects the wrong kind before reaching native |
| `drainPendingEvents()` | Returns the recorded taps, oldest first, with ids and timestamps, and removes them |
| `events` | Taps while the app runs and something listens |
| `reload({id})` | Redraws one control or all of them |
| `requestAddTile(id)` | Android 13+ system dialog. `unsupported` elsewhere, with no platform call |
| `isSupported()` | iOS 18+, Android API 24+, `false` where the plugin is absent |
| `QuickControlEventBatch` | `deltaFor`, `latestToggleFor`, `tapsFor` over a drained list |

### Exactly once

Every tap reaches Dart once, through `drainPendingEvents()` or through
`events`, never both. The `events` stream is built on the drain. Native sends
only a "something changed" ping, and Dart answers it by draining. While
nothing listens, nothing is drained, so taps wait instead of falling into an
empty stream. An app can drain on resume *and* listen while open without
double-counting.

One edge the stream has to cover itself: a ping's drain can still be in
flight when the last listener cancels. Native has removed those taps by
then, and a broadcast stream drops what nobody hears, so the plugin holds
them in memory and the next `drainPendingEvents()` returns them first.

`QuickControlEvent.id` is minted at the tap. If your own save can fail
partway through a batch, store the ids to make re-applying idempotent.

A drain removes events before your app has saved them. If the process dies
between the two, those taps are gone. Nothing short of a two-phase
acknowledge avoids that, and this package does not have one.

## Race safety

"A tap racing a drain" has two sides: the drain removes events while a tap is
adding one. Each platform prevents a lost or doubled tap differently, because
the writers live in different places.

**Android: one process, one lock.** The tile services are declared without
`android:process`, so they run in the app's main process. Every
read-modify-write of the pending list (a tile's append, the plugin's drain)
holds one process-wide lock from the read to a `commit()`. A tap either
commits before a drain reads, and is in its result, or after the drain
writes, and is in the next one. `PendingEventLogTest` races 4 threads against
a drainer and fails without the lock.

**iOS: two processes, no shared list.** The extension and the app are
separate processes, and `UserDefaults` has no cross-process compare-and-swap.
So there is no list to modify. Every tap is written under its own key,
`quick_controls.event.<uuid>`, which nothing ever rewrites. A drain snapshots
the event keys it can see, returns them, and removes exactly those keys. A
tap that lands mid-drain has a key the snapshot never saw, so it waits for
the next drain. Toggles need no read-modify-write either, because iOS hands
the intent the state being switched *to*.

The cost of key-per-event on iOS: a drain enumerates the suite, so it slows
as pending taps pile up. That is milliseconds at the tens of taps a row
counter accumulates. It took seconds at 6,000 in the stress check.

The one visible glitch: between a drain and the `setValue` that follows it, a
control that happened to redraw would show the old baseline without the
drained taps. `setValue` redraws it immediately afterwards.

## Android setup

None. The plugin's manifest declares **three** `TileService` slots, all
`android:enabled="false"`. `initialize` enables one per control through
`PackageManager.setComponentEnabledSetting` (with `DONT_KILL_APP`) and stores
its configuration in SharedPreferences. The host manifest is never touched.

- **A control keeps its slot across launches.** A tile the user placed is a
  slot, so reordering controls in Dart must not move them. A dropped control's
  slot is disabled and vanishes from Quick Settings. A new control takes a slot
  no control held last launch before a just-dropped one, so a placed tile does
  not turn into a different control; only when every slot was in use is a
  dropped one reused. A fourth control fails with
  `PlatformException(too_many_controls)`.
- **Several engines in one process are fine.** A background isolate (a push
  handler, `workmanager`) attaches its own plugin instance. Only the instance
  whose Dart side listens owns the ping sink, so another engine detaching does
  not cut the app off from live taps.
- **A counter shows `base + pending`** as the tile's subtitle on Android 10+,
  and on the label below that. A toggle shows active/inactive. A tap redraws
  the tile itself, so the number moves with the app closed.
- **`androidIcon`** names a drawable in *your* app's `res/drawable`. It must be
  single-colour, because Quick Settings tints it. An unknown name falls back
  to the plugin's plus-in-a-circle.
- **`opensApp: true`** opens the app after recording. Android 14 removed the
  `Intent` overload of `startActivityAndCollapse` for apps targeting it (it
  throws), so API 34+ uses the `PendingIntent` overload. On a locked device
  the tile calls `unlockAndRun` first.
- **Every recorded tap also broadcasts `TapBroadcast.ACTION`**
  (`com.jameskrupnik.quick_controls.action.TAP_RECORDED`), scoped
  to the host's own package, with the control id in the `controlId` extra.
  The engine ping only reaches a running engine; this reaches a manifest
  receiver with the app not running, e.g. a home screen widget that shows the
  same number and must redraw. A receiver with `android:exported="false"` and
  an intent filter for that action is enough.
- **Storage** is its own SharedPreferences file, not
  `FlutterSharedPreferences`, so `SharedPreferences.clear()` from Dart cannot
  wipe pending taps.

## iOS setup

A `ControlWidget` can only live in a **widget extension**, and a Flutter
plugin cannot add a target to your Xcode project. So on iOS you do these
steps once, by hand. `example/ios` has all of them done. Its
`ExampleControls` target is the reference.

**1. Add a Widget Extension target.** In Xcode: File › New › Target › Widget
Extension. Untick "Include Live Activity" and "Include Configuration App
Intent". Delete the generated Swift files except the bundle. If you already
have a widget extension, as Stitch Keeper's `CounterWidget` does, use that
one; controls can sit beside home screen widgets in one bundle.

Set the extension's deployment target to iOS 17 or 18. The kit guards
everything with `@available(iOS 18.0, *)`, so a lower target is fine as long
as the bundle does too (see step 6).

**2. Add the App Group to both targets.** Signing & Capabilities › + App
Groups, on **Runner and on the extension**, with the same id, e.g.
`group.com.example.app`. Register it in the developer portal. This is the id
you pass as `iosAppGroupId`.

`initialize` checks the entitlement with `containerURL(forSecurityApplicationGroupIdentifier:)`
and fails with `no_app_group` if Runner lacks it. Without that check every
write would appear to succeed and the extension would never see any of them.

**3. Tell the extension the group.** Add to the **extension's** Info.plist:

```xml
<key>QuickControlsAppGroup</key>
<string>group.com.example.app</string>
```

An intent carries only its parameters, and the extension has no Dart to ask,
so this key is how the kit finds the store.

**4. Add the kit to the extension target.** The kit is three files in this
package, at `ios/quick_controls/Sources/QuickControlsKit/`:

- `QuickControlsStore.swift`: the App Group store. The plugin compiles the
  same file.
- `QuickControlIntents.swift`: the `AppIntent`s that record taps.
- `QuickControlWidgets.swift`: generic `ControlWidget`s.

Copy them into your extension's folder and add them to the **extension
target only**, not Runner. Re-copy them when you upgrade this package. Each
file's header names the version, and the store's key layout is a contract
with the plugin's copy.

The example references them in place instead of copying, which works because
it lives inside the package. A pub-cache path is not stable enough to
reference from a real app.

**5. Privacy manifest.** The extension reads `UserDefaults`, a
required-reason API. Give it a `PrivacyInfo.xcprivacy` declaring
`NSPrivacyAccessedAPICategoryUserDefaults` with reason `1C8F.1`. The
plugin's own manifest already does this for Runner. The example's
`ExampleControls/PrivacyInfo.xcprivacy` can be copied as-is.

**6. Write the bundle.** One definition per control, whose `controlId` equals
the Dart `id`. Then list the controls:

```swift
import SwiftUI
import WidgetKit

enum RowsControl: QuickControlDefinition {
    static let controlId = "rows"          // == QuickControl id in Dart
    static let title = "Row"               // shown before the app first runs
    static let systemImage = "plus.circle"
}

@main
struct MyWidgets: WidgetBundle {
    var body: some Widget {
        MyExistingHomeScreenWidget()        // if you have one
        if #available(iOS 18.0, *) {
            QuickCounterControl<RowsControl>()
        }
    }
}
```

| Kit type | Kind | Tap records |
|---|---|---|
| `QuickCounterControl<D>` | counter | `+step` (the Dart `step`, default 1) |
| `QuickToggleControl<D>` | toggle | the new on/off state |
| `QuickButtonControl<D>` | button | a tap |
| `QuickOpeningButtonControl<D>` | button | a tap, then opens `D.openURL` |

A definition's `title` and `systemImage` are what the controls gallery shows,
and what the control shows before the app has called `initialize`. After
that, the Dart `title` and `iosSymbol` win.

**Only `QuickOpeningButtonControl` opens the app.** An intent's result type is
fixed at compile time, so on iOS "opens the app" is a choice of Swift type.
The Dart `opensApp` flag is Android-only for that reason.

Controls redraw after their own action. The kit also posts a Darwin
notification that a running app turns into an `events` ping. A suspended app
gets no notification, which is why the drain on resume is not optional.

## Example

`example/` declares a counter, a toggle and a button. It drains on launch and
on resume, listens while open, and has a button for Android's add-tile
dialog. Its app state is in memory only, so a cold start publishes 0. A real
app persists the count; that is the one thing the example deliberately does
not do.

```console
$ cd example
$ flutter build apk --debug
$ flutter build ios --simulator --no-codesign
```

## Development

```console
$ flutter analyze && flutter test                    # Dart
$ (cd example/android && ./gradlew :quick_controls:testDebugUnitTest)  # Kotlin
$ tool/store_race_check.sh                           # iOS store, macOS processes
```

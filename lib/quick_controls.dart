/// One Dart API for iOS 18 Control widgets and Android Quick Settings tiles.
///
/// Declare a control once and it appears in Control Center, on the Lock
/// Screen and under the Action button on iOS, and as a Quick Settings tile on
/// Android:
///
/// ```dart
/// await QuickControls.instance.initialize(
///   iosAppGroupId: 'group.com.example.app',
///   controls: const [
///     QuickControl.counter(id: 'row_plus_one', title: 'Row'),
///   ],
/// );
/// ```
///
/// ### Taps are recorded, not applied
///
/// A control runs while the app is not: in a widget extension on iOS, in a
/// `TileService` on Android. Neither touches app state. Each tap is written
/// as a pending event with its own id, the control redraws with the tap
/// counted in, and the app applies the events when it next runs — see
/// `QuickControls.drainPendingEvents`. One writer for app data is the whole
/// defence against a tap and a save racing.
///
/// ### iOS needs a widget extension
///
/// A `ControlWidget` can only be compiled into a widget extension, and a
/// Flutter plugin cannot add a target to the host's Xcode project. The package
/// ships the Swift for that extension as `QuickControlsKit`; the README walks
/// through adding it. Nothing on iOS appears until that is done.
library;

export 'src/pending_events.dart' show QuickControlEventBatch;
export 'src/quick_control.dart' show QuickControl, QuickControlKind;
export 'src/quick_control_event.dart' show QuickControlEvent;
export 'src/quick_controls_base.dart' show QuickControls;
export 'src/quick_tile_add_result.dart' show QuickTileAddResult;

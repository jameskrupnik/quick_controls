import 'package:flutter/foundation.dart';

/// What a control does when it is tapped, and so what a tap records.
enum QuickControlKind {
  /// A plain action. A tap records an event with no value.
  button,

  /// An on/off switch. A tap records the state it was switched *to*.
  toggle,

  /// A `+step` button that shows a number. A tap records a delta of `step`.
  counter,
}

/// One control, declared from Dart and shown on every surface the platform
/// has: a Control Center / Lock Screen / Action button control on iOS 18, a
/// Quick Settings tile on Android.
///
/// The [id] is the contract with native code. On iOS it is the `kind` of the
/// `ControlWidget` the host's widget extension declares, so it must match the
/// `controlId` of a `QuickControlDefinition` there, character for character.
/// On Android it is the key a tile slot is bound to, and it stays bound to
/// that slot across launches so a tile the user placed keeps showing the same
/// control.
@immutable
class QuickControl {
  /// A `+step` counter. What it shows is the last `QuickControls.setValue`
  /// plus every tap not yet drained, so a tap is visible at once without the
  /// app running.
  const QuickControl.counter({
    required this.id,
    required this.title,
    this.iosSymbol = 'plus.circle',
    this.androidIcon,
    this.step = 1,
    this.opensApp = false,
  }) : kind = QuickControlKind.counter;

  /// An on/off switch. What it shows is the last tap not yet drained, or the
  /// last `QuickControls.setToggled` if there is none.
  const QuickControl.toggle({
    required this.id,
    required this.title,
    this.iosSymbol = 'power',
    this.androidIcon,
    this.opensApp = false,
  })  : kind = QuickControlKind.toggle,
        step = 0;

  /// A plain action. Each tap is one event and carries no value.
  const QuickControl.button({
    required this.id,
    required this.title,
    this.iosSymbol = 'hand.tap',
    this.androidIcon,
    this.opensApp = false,
  })  : kind = QuickControlKind.button,
        step = 0;

  /// Letters, digits, `_`, `-` and `.` only, because it becomes a
  /// `ControlWidget` kind and part of a storage key on both platforms.
  final String id;

  /// Whether this is a counter, a toggle or a button.
  final QuickControlKind kind;

  /// The label on the control and the tile. A counter shows its number after
  /// it, or as the tile's subtitle on Android 10 and later.
  final String title;

  /// An SF Symbol name. Only the *default* on iOS: the symbol the extension
  /// draws before the app has ever run comes from its Swift definition.
  final String iosSymbol;

  /// The name of a drawable in the **host app's** resources, e.g.
  /// `ic_tile_row` for `res/drawable/ic_tile_row.xml`. `null`, or a name that
  /// does not resolve, falls back to the plugin's own plus-in-a-circle.
  ///
  /// Quick Settings tints tile icons to one colour, so this should be a
  /// single-colour vector, not a launcher icon.
  final String? androidIcon;

  /// How much one counter tap adds. Zero for the other kinds.
  final int step;

  /// **Android only.** Opens the app after recording the tap, collapsing the
  /// shade. Off by default because the point of a control is not opening the
  /// app.
  ///
  /// On iOS whether a control opens the app is fixed when the extension is
  /// compiled — an `AppIntent`'s result type is static — so it is set by
  /// `QuickControlDefinition.openURL` in Swift, not here.
  final bool opensApp;

  static final RegExp _validId = RegExp(r'^[A-Za-z0-9_.\-]+$');

  /// Whether [id] can be used as a control id. See [id] for why the
  /// character set is restricted.
  static bool isValidId(String id) => _validId.hasMatch(id);

  /// The shape both native halves read. Kind goes over as its name so the
  /// Swift and Kotlin enums can be matched by string rather than by index.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'kind': kind.name,
        'title': title,
        'iosSymbol': iosSymbol,
        'androidIcon': androidIcon,
        'step': step,
        'opensApp': opensApp,
      };

  @override
  bool operator ==(Object other) =>
      other is QuickControl &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.iosSymbol == iosSymbol &&
      other.androidIcon == androidIcon &&
      other.step == step &&
      other.opensApp == opensApp;

  @override
  int get hashCode =>
      Object.hash(id, kind, title, iosSymbol, androidIcon, step, opensApp);

  @override
  String toString() => 'QuickControl.${kind.name}($id, "$title")';
}

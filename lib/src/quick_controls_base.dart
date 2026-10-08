import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quick_controls/src/quick_control.dart';
import 'package:quick_controls/src/quick_control_event.dart';
import 'package:quick_controls/src/quick_tile_add_result.dart';

/// The entry point: declare controls, push their state out, and collect the
/// taps they recorded.
///
/// ### The rule this package is built around
///
/// **A control never changes app state.** The iOS extension and the Android
/// tile only *record* a tap — as a pending event with its own id — and show
/// the result optimistically. The app applies the events to its own state,
/// then calls [setValue] or [setToggled] to publish the new baseline. That
/// keeps one writer for the app's data, which is the only way two taps racing
/// a save cannot lose one.
///
/// ```dart
/// final events = await QuickControls.instance.drainPendingEvents();
/// rows += events.deltaFor('row_plus_one');
/// await QuickControls.instance.setValue('row_plus_one', rows);
/// ```
///
/// ### Exactly once
///
/// Every event is handed to Dart once. [drainPendingEvents] removes what it
/// returns in the same native critical section that read it; [events] is
/// built on the same drain, triggered by a ping from native while the app is
/// running and something is listening. So an app may use both — drain on
/// resume, listen while open — and no tap is counted twice.
class QuickControls {
  QuickControls._();

  /// The one instance, shared by every caller in the app.
  static final QuickControls instance = QuickControls._();

  /// The method channel to the native halves.
  ///
  /// Exposed only so tests can mock it.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('quick_controls');

  /// The event channel that carries "something changed" pings, never events.
  ///
  /// See [events]. Exposed only so tests can mock it.
  @visibleForTesting
  static const EventChannel pingChannel = EventChannel('quick_controls/pings');

  final Map<String, QuickControl> _controls = <String, QuickControl>{};

  StreamController<QuickControlEvent>? _events;
  StreamSubscription<Object?>? _pings;

  /// Serializes stream drains so a burst of pings cannot deliver a later
  /// batch before an earlier one.
  Future<void> _drainChain = Future<void>.value();

  /// Taps a stream drain took from native after its last listener left.
  /// Handed out first by the next [drainPendingEvents], so they are still
  /// delivered exactly once. Memory only, like any drained batch.
  List<QuickControlEvent> _undelivered = const <QuickControlEvent>[];

  /// Returns whether this device has the surface at all.
  ///
  /// That is iOS 18 and later for controls, Android 7 (API 24) and later for
  /// tiles. `false` on every other platform and on any platform where the
  /// plugin is not registered.
  ///
  /// On Android this is always `true` in practice, because the plugin's
  /// `minSdk` is 24. It is asked anyway so the answer comes from the device.
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Declares the app's controls and binds them to native storage.
  ///
  /// Call once per launch, before anything else, with the full list every
  /// time. Throws an [ArgumentError] for an id [QuickControl.isValidId]
  /// rejects, an id declared twice, or a counter with a zero step.
  ///
  /// [iosAppGroupId] is required on iOS: it is the App Group the widget
  /// extension shares with the app, e.g. `group.com.example.app`, and must be
  /// in both targets' entitlements. It is ignored on Android.
  ///
  /// On Android the list is also the tile allocation. A control keeps the
  /// slot it had last launch; a new one takes a free slot; a slot whose
  /// control is no longer listed is disabled and disappears from Quick
  /// Settings. The plugin's manifest declares three slots, so a fourth
  /// control fails with a [PlatformException] coded `too_many_controls`
  /// rather than becoming a tile that silently never appears. The count lives
  /// only in the manifest and the Kotlin that reads it.
  Future<void> initialize({
    required List<QuickControl> controls,
    String? iosAppGroupId,
  }) async {
    _validate(controls);
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (iosAppGroupId == null || iosAppGroupId.isEmpty)) {
      throw ArgumentError.value(
        iosAppGroupId,
        'iosAppGroupId',
        'is required on iOS: the extension can only read what the app writes '
            'into a shared App Group',
      );
    }
    await channel.invokeMethod<void>('initialize', <String, Object?>{
      'appGroupId': iosAppGroupId,
      'controls': controls.map((c) => c.toMap()).toList(),
    });
    _controls
      ..clear()
      ..addEntries(controls.map((c) => MapEntry(c.id, c)));
  }

  /// Publishes [value] as the baseline for counter [id].
  ///
  /// What the control shows is this plus any taps not yet drained, so call it
  /// *after* applying a drain, with the total that includes them.
  ///
  /// Throws a [StateError] if [id] was not passed to [initialize], and an
  /// [ArgumentError] if it is not a counter.
  Future<void> setValue(String id, int value) async {
    _require(id, QuickControlKind.counter, 'setValue');
    await channel.invokeMethod<void>('setValue', <String, Object?>{
      'id': id,
      'value': value,
    });
  }

  /// Publishes [isOn] as the state of toggle [id].
  ///
  /// A pending toggle tap still wins on screen until it is drained, since it
  /// is newer than anything the app has seen.
  ///
  /// Throws a [StateError] if [id] was not passed to [initialize], and an
  /// [ArgumentError] if it is not a toggle.
  Future<void> setToggled(String id, {required bool isOn}) async {
    _require(id, QuickControlKind.toggle, 'setToggled');
    await channel.invokeMethod<void>('setToggled', <String, Object?>{
      'id': id,
      'isOn': isOn,
    });
  }

  /// Returns every tap recorded since the last drain, oldest first, and
  /// removes them from native storage in the same step.
  ///
  /// Call on launch and on every resume. A tap that races this call is either
  /// in the result or left for the next drain — never both, never neither.
  /// See the README's "Race safety" section for how each platform holds that.
  ///
  /// Also returns, first, any taps an [events] drain took after its last
  /// listener had gone.
  Future<List<QuickControlEvent>> drainPendingEvents() async {
    final raw = await channel.invokeMethod<List<Object?>>('drainPendingEvents');
    // Held taps were drained earlier, so they are older than anything new.
    final held = _undelivered;
    _undelivered = const <QuickControlEvent>[];
    return [...held, ...parseQuickControlEvents(raw)];
  }

  /// Taps that happen while the app is running and this stream is listened
  /// to.
  ///
  /// Each ping from native triggers a drain, and the drained events come out
  /// here. **While nothing listens, nothing is drained**, so taps wait for
  /// [drainPendingEvents] instead of being dropped into an empty stream.
  ///
  /// iOS delivers pings only while the app is in memory and not suspended; a
  /// tap made from Control Center over a suspended app arrives through the
  /// drain on resume instead. That is why the drain is not optional.
  Stream<QuickControlEvent> get events {
    return (_events ??= StreamController<QuickControlEvent>.broadcast(
      onListen: () => _pings = pingChannel.receiveBroadcastStream().listen(
            (_) => _drainIntoStream(),
          ),
      onCancel: () async {
        await _pings?.cancel();
        _pings = null;
      },
    ))
        .stream;
  }

  void _drainIntoStream() {
    _drainChain = _drainChain.then((_) async {
      final controller = _events;
      if (controller == null || !controller.hasListener) return;
      try {
        final events = await drainPendingEvents();
        // The last listener may have left while native was answering, and a
        // broadcast stream drops what nobody hears. Native has removed these
        // already, so hold them for the next drain instead of losing them.
        if (!controller.hasListener || controller.isClosed) {
          _undelivered = [..._undelivered, ...events];
          return;
        }
        events.forEach(controller.add);
        // Any error, not only a PlatformException: an uncaught one would fail
        // this link of the chain, and every later link with it, so no ping
        // would drain again for the life of the process.
      } on Object catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    });
  }

  /// Asks the system to redraw [id], or every control when `null`.
  ///
  /// Setting a value already does this; call it after changing something the
  /// system cannot see, such as a drawable. Throws a [StateError] if [id] was
  /// not passed to [initialize].
  Future<void> reload({String? id}) async {
    if (id != null) _require(id, null, 'reload');
    await channel.invokeMethod<void>('reload', <String, Object?>{'id': id});
  }

  /// Shows the system's "Add tile to Quick Settings?" dialog for [id], on
  /// **Android 13+ only**.
  ///
  /// The app must be in the foreground. Throws a [StateError] if [id] was not
  /// passed to [initialize].
  ///
  /// Everywhere else this returns [QuickTileAddResult.unsupported] without a
  /// platform call. iOS has no equivalent: a person adds a control from the
  /// Control Center editor themselves.
  Future<QuickTileAddResult> requestAddTile(String id) async {
    _require(id, null, 'requestAddTile');
    if (defaultTargetPlatform != TargetPlatform.android) {
      return QuickTileAddResult.unsupported;
    }
    final name = await channel.invokeMethod<String>(
      'requestAddTile',
      <String, Object?>{'id': id},
    );
    return quickTileAddResultNamed(name);
  }

  /// Catches in Dart what native would otherwise catch as a silent no-op:
  /// ids that cannot be storage keys, and two controls fighting over one id.
  static void _validate(List<QuickControl> controls) {
    final seen = <String>{};
    for (final control in controls) {
      if (!QuickControl.isValidId(control.id)) {
        throw ArgumentError.value(
          control.id,
          'id',
          'may contain only letters, digits, "_", "-" and "."',
        );
      }
      if (!seen.add(control.id)) {
        throw ArgumentError.value(control.id, 'id', 'is declared twice');
      }
      if (control.kind == QuickControlKind.counter && control.step == 0) {
        throw ArgumentError.value(control.step, 'step', 'must not be zero');
      }
    }
  }

  void _require(String id, QuickControlKind? kind, String method) {
    final control = _controls[id];
    if (control == null) {
      throw StateError(
        '$method("$id"): no control with that id. Call initialize() first, '
        'and include it in the list.',
      );
    }
    if (kind != null && control.kind != kind) {
      throw ArgumentError.value(
        id,
        'id',
        'is a ${control.kind.name}; $method applies only to a ${kind.name}',
      );
    }
  }

  /// Forgets the declared controls and drops the event stream, for tests.
  @visibleForTesting
  Future<void> debugReset() async {
    _controls.clear();
    await _pings?.cancel();
    _pings = null;
    await _events?.close();
    _events = null;
    _drainChain = Future<void>.value();
    _undelivered = const <QuickControlEvent>[];
  }
}

import 'package:flutter/foundation.dart';
import 'package:quick_controls/src/quick_control.dart';

/// One tap on a control, recorded by the extension or tile and handed to the
/// app exactly once — either by `QuickControls.drainPendingEvents` or on
/// `QuickControls.events`, never both.
///
/// The [id] is unique per tap and minted where the tap happened. An app that
/// persists taps somewhere that can fail halfway can store it to make
/// re-applying a batch idempotent.
@immutable
class QuickControlEvent {
  /// Creates an event. Normally built by the plugin, not by apps.
  const QuickControlEvent({
    required this.id,
    required this.controlId,
    required this.kind,
    required this.recordedAt,
    this.delta = 0,
    this.isOn,
  });

  /// Unique per tap, minted where the tap happened.
  final String id;

  /// The [QuickControl.id] of the control that was tapped.
  final String controlId;

  /// The kind of control that was tapped.
  final QuickControlKind kind;

  /// When the tap happened, by the device clock at the time — not when it was
  /// drained, which may be days later.
  final DateTime recordedAt;

  /// What a counter tap adds. Zero for a button or toggle.
  final int delta;

  /// The state a toggle tap switched *to*. `null` for the other kinds.
  final bool? isOn;

  /// Reads one event from the native map, or returns `null` if it is not
  /// one.
  ///
  /// Lenient on purpose. By the time this runs the batch has already been
  /// removed from native storage, so throwing on one malformed entry would
  /// lose every good entry beside it. A bad entry is dropped; the rest stand.
  static QuickControlEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final controlId = raw['controlId'];
    final kind = _kindNamed(raw['kind']);
    final recordedAt = raw['recordedAt'];
    if (id is! String || controlId is! String || kind == null) return null;
    if (recordedAt is! num) return null;

    final delta = raw['delta'];
    final isOn = raw['isOn'];
    if (kind == QuickControlKind.toggle && isOn is! bool) return null;

    return QuickControlEvent(
      id: id,
      controlId: controlId,
      kind: kind,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(recordedAt.toInt()),
      delta:
          kind == QuickControlKind.counter && delta is num ? delta.toInt() : 0,
      isOn: kind == QuickControlKind.toggle ? isOn as bool? : null,
    );
  }

  /// Parses a drained batch, dropping anything unreadable (see [tryParse]),
  /// and returns it in the order the taps happened.
  static List<QuickControlEvent> parseAll(Object? raw) {
    if (raw is! List) return const <QuickControlEvent>[];
    final events = raw.map(tryParse).whereType<QuickControlEvent>().toList()
      // A stable sort: two taps in one millisecond keep native's order.
      ..sort(_byRecordedAt);
    return events;
  }

  static int _byRecordedAt(QuickControlEvent a, QuickControlEvent b) =>
      a.recordedAt.compareTo(b.recordedAt);

  static QuickControlKind? _kindNamed(Object? name) {
    for (final kind in QuickControlKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is QuickControlEvent &&
      other.id == id &&
      other.controlId == controlId &&
      other.kind == kind &&
      other.recordedAt == recordedAt &&
      other.delta == delta &&
      other.isOn == isOn;

  @override
  int get hashCode => Object.hash(id, controlId, kind, recordedAt, delta, isOn);

  @override
  String toString() => switch (kind) {
        QuickControlKind.counter => 'QuickControlEvent($controlId +$delta)',
        QuickControlKind.toggle => 'QuickControlEvent($controlId -> $isOn)',
        QuickControlKind.button => 'QuickControlEvent($controlId tap)',
      };
}

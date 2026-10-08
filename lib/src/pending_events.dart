import 'package:quick_controls/src/quick_control.dart';
import 'package:quick_controls/src/quick_control_event.dart';

/// Arithmetic over a drained batch: the answers an app usually wants from it.
///
/// Pure functions over a list, so the arithmetic an app applies to its own
/// state is testable without a platform channel.
extension QuickControlEventBatch on Iterable<QuickControlEvent> {
  /// Returns the net counter change for [controlId], the sum of its deltas.
  int deltaFor(String controlId) => where(
        (e) => e.controlId == controlId && e.kind == QuickControlKind.counter,
      ).fold(0, (sum, e) => sum + e.delta);

  /// Returns the state [controlId] was last switched to, or `null` if it was
  /// not toggled in this batch.
  ///
  /// "Last" is by [QuickControlEvent.recordedAt], not list position, so it
  /// holds for a batch that was not sorted.
  bool? latestToggleFor(String controlId) {
    QuickControlEvent? latest;
    for (final e in this) {
      if (e.controlId != controlId || e.kind != QuickControlKind.toggle) {
        continue;
      }
      if (latest == null || !e.recordedAt.isBefore(latest.recordedAt)) {
        latest = e;
      }
    }
    return latest?.isOn;
  }

  /// Returns how many times the button [controlId] was pressed.
  int tapsFor(String controlId) => where(
        (e) => e.controlId == controlId && e.kind == QuickControlKind.button,
      ).length;
}

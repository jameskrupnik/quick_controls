import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';

void main() {
  QuickControlEvent counter(String controlId, int delta, [int at = 0]) =>
      QuickControlEvent(
        id: '$controlId-$delta-$at',
        controlId: controlId,
        kind: QuickControlKind.counter,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(at),
        delta: delta,
      );

  QuickControlEvent toggle(
    String controlId, {
    required bool isOn,
    int at = 0,
  }) =>
      QuickControlEvent(
        id: '$controlId-$isOn-$at',
        controlId: controlId,
        kind: QuickControlKind.toggle,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(at),
        isOn: isOn,
      );

  QuickControlEvent tap(String controlId, [int at = 0]) => QuickControlEvent(
        id: '$controlId-tap-$at',
        controlId: controlId,
        kind: QuickControlKind.button,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(at),
      );

  test('deltaFor sums one counter and ignores the others', () {
    final batch = [counter('rows', 1), counter('rows', 1, 1), counter('st', 5)];
    expect(batch.deltaFor('rows'), 2);
    expect(batch.deltaFor('st'), 5);
    expect(batch.deltaFor('none'), 0);
  });

  test('deltaFor handles negative steps', () {
    expect([counter('rows', -1), counter('rows', 3, 1)].deltaFor('rows'), 2);
  });

  test('latestToggleFor takes the newest by time, not by position', () {
    final batch = [
      toggle('light', isOn: false, at: 30),
      toggle('light', isOn: true, at: 10),
    ];
    expect(batch.latestToggleFor('light'), isFalse);
    expect(batch.latestToggleFor('other'), isNull);
  });

  test('latestToggleFor lets the later of two same-time taps win', () {
    final batch = [
      toggle('light', isOn: true, at: 10),
      toggle('light', isOn: false, at: 10),
    ];
    expect(batch.latestToggleFor('light'), isFalse);
  });

  test('tapsFor counts button presses only', () {
    final batch = [tap('go'), tap('go', 1), counter('go', 1)];
    expect(batch.tapsFor('go'), 2);
  });
}

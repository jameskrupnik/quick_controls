import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';
import 'package:quick_controls/src/quick_control_event.dart';

void main() {
  Map<String, Object?> raw({
    String id = 'e1',
    String controlId = 'rows',
    Object? kind = 'counter',
    Object? recordedAt = 1000,
    Object? delta = 1,
    Object? isOn,
  }) =>
      <String, Object?>{
        'id': id,
        'controlId': controlId,
        'kind': kind,
        'recordedAt': recordedAt,
        'delta': delta,
        'isOn': isOn,
      };

  group('tryParseQuickControlEvent', () {
    test('reads a counter tap', () {
      final event = tryParseQuickControlEvent(raw(delta: 2));
      expect(
        event,
        QuickControlEvent(
          id: 'e1',
          controlId: 'rows',
          kind: QuickControlKind.counter,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          delta: 2,
        ),
      );
    });

    test('reads a toggle tap and ignores any delta on it', () {
      final event = tryParseQuickControlEvent(
        raw(kind: 'toggle', isOn: true, delta: 5),
      );
      expect(event?.isOn, isTrue);
      expect(event?.delta, 0);
    });

    test('reads a button tap with neither delta nor state', () {
      final event = tryParseQuickControlEvent(
        raw(kind: 'button', isOn: true, delta: 5),
      );
      expect(event?.kind, QuickControlKind.button);
      expect(event?.delta, 0);
      expect(event?.isOn, isNull);
    });

    test('accepts a timestamp that arrives as a double', () {
      // NSNumber from UserDefaults can decode as a double on the Dart side.
      final event = tryParseQuickControlEvent(raw(recordedAt: 1500.0));
      expect(event?.recordedAt.millisecondsSinceEpoch, 1500);
    });

    test('rejects what is not an event', () {
      expect(tryParseQuickControlEvent(null), isNull);
      expect(tryParseQuickControlEvent('rows'), isNull);
      expect(tryParseQuickControlEvent(raw(kind: 'slider')), isNull);
      expect(tryParseQuickControlEvent(raw(recordedAt: '1000')), isNull);
      expect(tryParseQuickControlEvent(raw(kind: 'toggle')), isNull);
      expect(
        tryParseQuickControlEvent(<String, Object?>{'id': 'e1'}),
        isNull,
      );
    });

    test('a counter tap with no delta counts as zero, not a crash', () {
      expect(tryParseQuickControlEvent(raw(delta: null))?.delta, 0);
    });
  });

  group('parseQuickControlEvents', () {
    test('drops malformed entries and keeps the good ones', () {
      final events = parseQuickControlEvents(<Object?>[
        raw(id: 'a'),
        'garbage',
        raw(id: 'b', kind: 'nope'),
        raw(id: 'c'),
      ]);
      expect(events.map((e) => e.id), <String>['a', 'c']);
    });

    test('orders by recordedAt, keeping native order on a tie', () {
      final events = parseQuickControlEvents(<Object?>[
        raw(id: 'late', recordedAt: 3000),
        raw(id: 'tie1', recordedAt: 2000),
        raw(id: 'early', recordedAt: 500),
        raw(id: 'tie2', recordedAt: 2000),
      ]);
      expect(
        events.map((e) => e.id),
        <String>['early', 'tie1', 'tie2', 'late'],
      );
    });

    test('treats null or a non-list as empty', () {
      expect(parseQuickControlEvents(null), isEmpty);
      expect(parseQuickControlEvents(<String, Object?>{}), isEmpty);
    });
  });

  test('toString names the control and the change', () {
    expect(
      tryParseQuickControlEvent(raw(delta: 3)).toString(),
      'QuickControlEvent(rows +3)',
    );
    expect(
      tryParseQuickControlEvent(raw(kind: 'toggle', isOn: true)).toString(),
      'QuickControlEvent(rows -> true)',
    );
    expect(
      tryParseQuickControlEvent(raw(kind: 'button')).toString(),
      'QuickControlEvent(rows tap)',
    );
  });

  test('equality and hashCode are by value', () {
    final a = tryParseQuickControlEvent(raw(delta: 2));
    final b = tryParseQuickControlEvent(raw(delta: 2));
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(tryParseQuickControlEvent(raw(delta: 3)))));
  });

  group('QuickControlEvent rejects fields its kind cannot have', () {
    // An app building a batch for its own tests used to be able to make a
    // toggle tap with no state. latestToggleFor then answered null ("not
    // toggled in this batch") for a batch whose newest event was a toggle,
    // and a counter's delta on a button was silently never counted.
    QuickControlEvent make(
      QuickControlKind kind, {
      int delta = 0,
      bool? isOn,
    }) =>
        QuickControlEvent(
          id: 'e',
          controlId: 'c',
          kind: kind,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(0),
          delta: delta,
          isOn: isOn,
        );

    test('a toggle without the state it switched to', () {
      expect(() => make(QuickControlKind.toggle), throwsAssertionError);
    });

    test('a state on a counter or a button', () {
      expect(
        () => make(QuickControlKind.counter, delta: 1, isOn: true),
        throwsAssertionError,
      );
      expect(
        () => make(QuickControlKind.button, isOn: false),
        throwsAssertionError,
      );
    });

    test('a delta on a toggle or a button', () {
      expect(
        () => make(QuickControlKind.toggle, delta: 1, isOn: true),
        throwsAssertionError,
      );
      expect(
        () => make(QuickControlKind.button, delta: 1),
        throwsAssertionError,
      );
    });

    test('each kind with exactly its own field is fine', () {
      expect(make(QuickControlKind.counter, delta: -2).delta, -2);
      expect(make(QuickControlKind.toggle, isOn: false).isOn, isFalse);
      expect(make(QuickControlKind.button).isOn, isNull);
    });
  });
}

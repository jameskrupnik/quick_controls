import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';

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

  group('QuickControlEvent.tryParse', () {
    test('reads a counter tap', () {
      final event = QuickControlEvent.tryParse(raw(delta: 2));
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
      final event = QuickControlEvent.tryParse(
        raw(kind: 'toggle', isOn: true, delta: 5),
      );
      expect(event?.isOn, isTrue);
      expect(event?.delta, 0);
    });

    test('reads a button tap with neither delta nor state', () {
      final event = QuickControlEvent.tryParse(
        raw(kind: 'button', isOn: true, delta: 5),
      );
      expect(event?.kind, QuickControlKind.button);
      expect(event?.delta, 0);
      expect(event?.isOn, isNull);
    });

    test('accepts a timestamp that arrives as a double', () {
      // NSNumber from UserDefaults can decode as a double on the Dart side.
      final event = QuickControlEvent.tryParse(raw(recordedAt: 1500.0));
      expect(event?.recordedAt.millisecondsSinceEpoch, 1500);
    });

    test('rejects what is not an event', () {
      expect(QuickControlEvent.tryParse(null), isNull);
      expect(QuickControlEvent.tryParse('rows'), isNull);
      expect(QuickControlEvent.tryParse(raw(kind: 'slider')), isNull);
      expect(QuickControlEvent.tryParse(raw(recordedAt: '1000')), isNull);
      expect(QuickControlEvent.tryParse(raw(kind: 'toggle')), isNull);
      expect(
        QuickControlEvent.tryParse(<String, Object?>{'id': 'e1'}),
        isNull,
      );
    });

    test('a counter tap with no delta counts as zero, not a crash', () {
      expect(QuickControlEvent.tryParse(raw(delta: null))?.delta, 0);
    });
  });

  group('QuickControlEvent.parseAll', () {
    test('drops malformed entries and keeps the good ones', () {
      final events = QuickControlEvent.parseAll(<Object?>[
        raw(id: 'a'),
        'garbage',
        raw(id: 'b', kind: 'nope'),
        raw(id: 'c'),
      ]);
      expect(events.map((e) => e.id), <String>['a', 'c']);
    });

    test('orders by recordedAt, keeping native order on a tie', () {
      final events = QuickControlEvent.parseAll(<Object?>[
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
      expect(QuickControlEvent.parseAll(null), isEmpty);
      expect(QuickControlEvent.parseAll(<String, Object?>{}), isEmpty);
    });
  });

  test('toString names the control and the change', () {
    expect(
      QuickControlEvent.tryParse(raw(delta: 3)).toString(),
      'QuickControlEvent(rows +3)',
    );
  });
}

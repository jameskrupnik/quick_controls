import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';

void main() {
  const rows = QuickControl.counter(id: 'rows', title: 'Row');
  const light = QuickControl.toggle(id: 'light', title: 'Light');
  const go = QuickControl.button(id: 'go', title: 'Go', opensApp: true);

  group('QuickControl', () {
    test('isValidId allows the storage-safe set only', () {
      expect(QuickControl.isValidId('row_plus-1.v2'), isTrue);
      expect(QuickControl.isValidId(''), isFalse);
      expect(QuickControl.isValidId('row/1'), isFalse);
      expect(QuickControl.isValidId('row 1'), isFalse);
    });

    test('non-counters carry no step', () {
      expect(light.step, 0);
      expect(go.step, 0);
    });

    test('equality is by value', () {
      expect(
        const QuickControl.counter(id: 'rows', title: 'Row'),
        equals(rows),
      );
      expect(
        rows.hashCode,
        const QuickControl.counter(id: 'rows', title: 'Row').hashCode,
      );
      expect(rows, isNot(equals(light)));
    });

    test('toString names the kind, id and title', () {
      expect(rows.toString(), 'QuickControl.counter(rows, "Row")');
    });
  });
}

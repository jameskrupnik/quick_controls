import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';
import 'package:quick_controls_example/main.dart';

void main() {
  testWidgets('says so when the platform has no controls', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      QuickControls.channel,
      (call) async => call.method == 'isSupported' ? false : null,
    );
    await tester.pumpWidget(const QuickControlsExampleApp());
    await tester.pump();
    expect(
      find.text('Controls are not supported on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('applies drained taps on start', (tester) async {
    var drained = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      QuickControls.channel,
      (call) async {
        switch (call.method) {
          case 'isSupported':
            return true;
          case 'drainPendingEvents':
            if (drained) return <Object?>[];
            drained = true;
            return <Object?>[
              for (var i = 0; i < 3; i++)
                <String, Object?>{
                  'id': 'e$i',
                  'controlId': 'rows',
                  'kind': 'counter',
                  'recordedAt': i,
                  'delta': 1,
                },
            ];
        }
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      QuickControls.pingChannel,
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    await tester.pumpWidget(const QuickControlsExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Ready.'), findsOneWidget);
  });
}

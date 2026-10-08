import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_controls/quick_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final controls = QuickControls.instance;
  final log = <MethodCall>[];

  /// What the fake native side hands back from the next drain(s).
  var pending = <Object?>[];
  Object? addTileAnswer = 'added';
  MockStreamHandlerEventSink? pingSink;

  const rows = QuickControl.counter(id: 'rows', title: 'Row');
  const light = QuickControl.toggle(id: 'light', title: 'Light');
  const go = QuickControl.button(id: 'go', title: 'Go', opensApp: true);

  Map<String, Object?> tap(String id, int at) => <String, Object?>{
        'id': 'evt-$at',
        'controlId': id,
        'kind': 'counter',
        'recordedAt': at,
        'delta': 1,
      };

  setUp(() async {
    log.clear();
    pending = <Object?>[];
    addTileAnswer = 'added';
    pingSink = null;
    await controls.debugReset();
    messenger
      ..setMockMethodCallHandler(QuickControls.channel, (call) async {
        log.add(call);
        switch (call.method) {
          case 'isSupported':
            return true;
          case 'drainPendingEvents':
            // Native removes what it returns; so does this fake.
            final batch = pending;
            pending = <Object?>[];
            return batch;
          case 'requestAddTile':
            return addTileAnswer;
        }
        return null;
      })
      ..setMockStreamHandler(
        QuickControls.pingChannel,
        MockStreamHandler.inline(
          onListen: (_, sink) => pingSink = sink,
          onCancel: (_) => pingSink = null,
        ),
      );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger
      ..setMockMethodCallHandler(QuickControls.channel, null)
      ..setMockStreamHandler(QuickControls.pingChannel, null);
  });

  Future<void> initialize([
    List<QuickControl> list = const [rows, light, go],
  ]) =>
      controls.initialize(controls: list, iosAppGroupId: 'group.test');

  group('isSupported', () {
    test('asks the platform', () async {
      expect(await controls.isSupported(), isTrue);
      expect(log.single.method, 'isSupported');
    });

    test('is false where the plugin is not registered', () async {
      messenger.setMockMethodCallHandler(QuickControls.channel, null);
      expect(await controls.isSupported(), isFalse);
    });
  });

  group('initialize', () {
    test('sends the app group and every control in the native shape', () async {
      await initialize();
      final call = log.single;
      expect(call.method, 'initialize');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['appGroupId'], 'group.test');
      final sent = args['controls']! as List<Object?>;
      expect(sent, hasLength(3));
      expect(sent.first, <String, Object?>{
        'id': 'rows',
        'kind': 'counter',
        'title': 'Row',
        'iosSymbol': 'plus.circle',
        'androidIcon': null,
        'step': 1,
        'opensApp': false,
      });
      expect((sent.last! as Map<Object?, Object?>)['opensApp'], isTrue);
    });

    test('rejects an id that cannot be a storage key', () async {
      expect(
        () => initialize(const [QuickControl.counter(id: 'a b', title: 'x')]),
        throwsArgumentError,
      );
      expect(log, isEmpty);
    });

    test('rejects the same id twice', () {
      expect(() => initialize(const [rows, rows]), throwsArgumentError);
    });

    test('rejects a counter that would count nothing', () {
      expect(
        () => initialize(
          const [QuickControl.counter(id: 'z', title: 'z', step: 0)],
        ),
        throwsArgumentError,
      );
    });

    test('requires an app group on iOS and nowhere else', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        () => controls.initialize(controls: const [rows]),
        throwsArgumentError,
      );
      expect(
        () => controls.initialize(controls: const [rows], iosAppGroupId: ''),
        throwsArgumentError,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await controls.initialize(controls: const [rows]);
      expect(log.single.method, 'initialize');
    });

    test('a native refusal surfaces and declares nothing', () async {
      messenger.setMockMethodCallHandler(QuickControls.channel, (call) async {
        throw PlatformException(code: 'too_many_controls');
      });
      await expectLater(initialize(), throwsA(isA<PlatformException>()));
      expect(() => controls.setValue('rows', 1), throwsStateError);
    });
  });

  group('setValue and setToggled', () {
    setUp(initialize);

    test('push the value for the right id', () async {
      await controls.setValue('rows', 42);
      await controls.setToggled('light', isOn: true);
      expect(log.skip(1).map((c) => [c.method, c.arguments]), [
        [
          'setValue',
          {'id': 'rows', 'value': 42},
        ],
        [
          'setToggled',
          {'id': 'light', 'isOn': true},
        ],
      ]);
    });

    test('refuse the wrong kind before reaching native', () {
      expect(() => controls.setValue('light', 1), throwsArgumentError);
      expect(
        () => controls.setToggled('rows', isOn: true),
        throwsArgumentError,
      );
      expect(log, hasLength(1));
    });

    test('refuse an undeclared id', () {
      expect(() => controls.setValue('nope', 1), throwsStateError);
    });
  });

  group('drainPendingEvents', () {
    setUp(initialize);

    test('returns parsed events, oldest first', () async {
      pending = [tap('rows', 20), tap('rows', 10)];
      final events = await controls.drainPendingEvents();
      expect(events.map((e) => e.id), ['evt-10', 'evt-20']);
      expect(events.deltaFor('rows'), 2);
    });

    test('a second drain gets only what arrived since', () async {
      pending = [tap('rows', 1)];
      await controls.drainPendingEvents();
      expect(await controls.drainPendingEvents(), isEmpty);
    });

    test('an empty native answer is an empty list', () async {
      messenger.setMockMethodCallHandler(QuickControls.channel, (_) async {
        return null;
      });
      expect(await controls.drainPendingEvents(), isEmpty);
    });
  });

  group('events', () {
    setUp(initialize);

    test('a ping drains and emits the batch', () async {
      final received = <QuickControlEvent>[];
      final sub = controls.events.listen(received.add);
      await pumpEventQueue();
      expect(pingSink, isNotNull);

      pending = [tap('rows', 1), tap('rows', 2)];
      pingSink!.success(<String, Object?>{'controlId': 'rows'});
      await pumpEventQueue();

      expect(received.map((e) => e.id), ['evt-1', 'evt-2']);
      expect(pending, isEmpty);
      await sub.cancel();
    });

    test('with no listener, nothing is drained', () async {
      final sub = controls.events.listen((_) {});
      await pumpEventQueue();
      final sink = pingSink!;
      await sub.cancel();
      await pumpEventQueue();

      pending = [tap('rows', 1)];
      sink.success(null);
      await pumpEventQueue();

      expect(log.where((c) => c.method == 'drainPendingEvents'), isEmpty);
      expect(await controls.drainPendingEvents(), hasLength(1));
    });

    test('a burst of pings delivers each event once, in order', () async {
      final received = <String>[];
      final sub = controls.events.listen((e) => received.add(e.id));
      await pumpEventQueue();

      pending = [tap('rows', 1)];
      pingSink!.success(null);
      pingSink!.success(null);
      pingSink!.success(null);
      await pumpEventQueue();

      expect(received, ['evt-1']);
      await sub.cancel();
    });

    test('a failing drain reaches the stream as an error', () async {
      final errors = <Object>[];
      final sub = controls.events.listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      messenger.setMockMethodCallHandler(QuickControls.channel, (_) async {
        throw PlatformException(code: 'no_app_group');
      });

      pingSink!.success(null);
      await pumpEventQueue();

      expect(errors.single, isA<PlatformException>());
      await sub.cancel();
    });

    test('taps drained as the last listener leaves go to the next drain',
        () async {
      final sub = controls.events.listen((_) {});
      await pumpEventQueue();
      final sink = pingSink!;

      // Hold the stream's drain open in native, as a slow platform reply.
      final reply = Completer<void>();
      messenger.setMockMethodCallHandler(QuickControls.channel, (call) async {
        if (call.method != 'drainPendingEvents') return null;
        final batch = pending;
        pending = <Object?>[];
        await reply.future;
        return batch;
      });
      pending = [tap('rows', 1), tap('rows', 2)];
      sink.success(null);
      await pumpEventQueue();

      // The listener goes while native has already removed the taps.
      await sub.cancel();
      reply.complete();
      await pumpEventQueue();

      final next = await controls.drainPendingEvents();
      expect(next.map((e) => e.id), ['evt-1', 'evt-2']);
      expect(await controls.drainPendingEvents(), isEmpty);
    });

    test('a drain failing with any error does not stop later pings', () async {
      final received = <String>[];
      final errors = <Object>[];
      final sub = controls.events.listen(
        (e) => received.add(e.id),
        onError: errors.add,
      );
      await pumpEventQueue();

      var calls = 0;
      messenger.setMockMethodCallHandler(QuickControls.channel, (call) async {
        if (call.method != 'drainPendingEvents') return null;
        // Not a PlatformException: the first drain answers something that
        // is not a list.
        if (calls++ == 0) return 'not a list';
        final batch = pending;
        pending = <Object?>[];
        return batch;
      });

      pingSink!.success(null);
      await pumpEventQueue();
      pending = [tap('rows', 1)];
      pingSink!.success(null);
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(received, ['evt-1']);
      await sub.cancel();
    });
  });

  group('reload', () {
    setUp(initialize);

    test('sends one id or none', () async {
      await controls.reload(id: 'rows');
      await controls.reload();
      expect(log.skip(1).map((c) => c.arguments), [
        {'id': 'rows'},
        {'id': null},
      ]);
    });

    test('refuses an undeclared id', () {
      expect(() => controls.reload(id: 'nope'), throwsStateError);
    });
  });

  group('requestAddTile', () {
    setUp(initialize);

    test('maps the native answer on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      for (final answer in QuickTileAddResult.values) {
        addTileAnswer = answer.name;
        expect(await controls.requestAddTile('rows'), answer);
      }
    });

    test('treats an unknown answer as failed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTileAnswer = 'something_new';
      expect(await controls.requestAddTile('rows'), QuickTileAddResult.failed);
    });

    test('is unsupported on iOS without a platform call', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        await controls.requestAddTile('rows'),
        QuickTileAddResult.unsupported,
      );
      expect(log.where((c) => c.method == 'requestAddTile'), isEmpty);
    });
  });

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

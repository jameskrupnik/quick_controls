import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quick_controls/quick_controls.dart';

void main() => runApp(const QuickControlsExampleApp());

/// Must match the App Group in both `Runner.entitlements` and
/// `ExampleControls.entitlements`, and `QuickControlsAppGroup` in the
/// extension's Info.plist.
const appGroupId = 'group.com.jameskrupnik.quickcontrols.example';

/// The three kinds, one each. The ids must match the `controlId`s in
/// `ios/ExampleControls/ExampleControls.swift`.
const rows = QuickControl.counter(id: 'rows', title: 'Row');
const light = QuickControl.toggle(
  id: 'light',
  title: 'Light',
  iosSymbol: 'lightbulb',
);
const ping = QuickControl.button(id: 'ping', title: 'Ping', opensApp: true);

/// A counter, a toggle and a button, applied the way a real app should:
/// drain on launch and every resume, listen while open, then publish.
///
/// State is held in memory only, which a real app must not do: on a cold
/// start this publishes 0 and the control's number resets. Stitch Keeper's
/// Hive box is the real version of `_rows`.
class QuickControlsExampleApp extends StatefulWidget {
  const QuickControlsExampleApp({super.key});

  @override
  State<QuickControlsExampleApp> createState() =>
      _QuickControlsExampleAppState();
}

class _QuickControlsExampleAppState extends State<QuickControlsExampleApp> {
  final QuickControls _controls = QuickControls.instance;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<QuickControlEvent>? _live;

  int _rows = 0;
  bool _light = false;
  int _pings = 0;
  String _status = 'Starting…';

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _drain);
    unawaited(_start());
  }

  Future<void> _start() async {
    final supported = await _controls.isSupported();
    if (!supported) {
      setState(() => _status = 'Controls are not supported on this device.');
      return;
    }
    await _controls.initialize(
      iosAppGroupId: appGroupId,
      controls: const [rows, light, ping],
    );
    _live = _controls.events.listen((event) => _apply([event]));
    await _drain();
    setState(() => _status = 'Ready.');
  }

  Future<void> _drain() async => _apply(await _controls.drainPendingEvents());

  /// Applies a batch to app state, then publishes the new baselines. The
  /// order matters: publishing first would show the old number minus the
  /// taps just drained.
  Future<void> _apply(List<QuickControlEvent> events) async {
    if (events.isEmpty) return;
    setState(() {
      _rows += events.deltaFor(rows.id);
      _light = events.latestToggleFor(light.id) ?? _light;
      _pings += events.tapsFor(ping.id);
    });
    await _publish();
  }

  Future<void> _publish() async {
    await _controls.setValue(rows.id, _rows);
    await _controls.setToggled(light.id, isOn: _light);
  }

  Future<void> _addTile() async {
    final result = await _controls.requestAddTile(rows.id);
    setState(() => _status = 'Add tile: ${result.name}');
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_live?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('quick_controls')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_status),
            ListTile(
              title: const Text('Rows'),
              trailing: Text('$_rows'),
              onTap: () {
                setState(() => _rows++);
                unawaited(_publish());
              },
            ),
            SwitchListTile(
              title: const Text('Light'),
              value: _light,
              onChanged: (value) {
                setState(() => _light = value);
                unawaited(_publish());
              },
            ),
            ListTile(title: const Text('Pings'), trailing: Text('$_pings')),
            FilledButton(
              onPressed: _addTile,
              child: const Text('Add the Rows tile (Android 13+)'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:blood_pressure_app/core/widgets/visible_periodic_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a clock enabled after mount refreshes immediately', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    var ticks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, value, _) =>
              _Clock(onTick: () => ticks++, enabled: () => value),
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    expect(ticks, 0);
    enabled.value = true;
    await tester.pump();
    expect(
      ticks,
      1,
      reason: 'Do not display stale data until the first timer tick.',
    );
  });

  testWidgets('stops hidden and background clocks and refreshes on return', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    var ticks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, value, child) =>
              TickerMode(enabled: value, child: child!),
          child: _Clock(onTick: () => ticks++),
        ),
      ),
    );
    final initial = ticks;
    expect(initial, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(ticks, initial + 1);
    visible.value = false;
    await tester.pump();
    final hidden = ticks;
    await tester.pump(const Duration(minutes: 5));
    expect(ticks, hidden);
    visible.value = true;
    await tester.pump();
    expect(ticks, hidden + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = ticks;
    await tester.pump(const Duration(minutes: 5));
    expect(ticks, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ticks, paused + 1);
    await tester.pump(const Duration(seconds: 10));
    expect(ticks, paused + 2);
    await tester.pumpWidget(const SizedBox.shrink());
    final disposed = ticks;
    await tester.pump(const Duration(minutes: 5));
    expect(ticks, disposed);
  });

  testWidgets('a covering dialog suspends the underlying clock', (
    tester,
  ) async {
    var ticks = 0;
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return _Clock(onTick: () => ticks++);
          },
        ),
      ),
    );
    showDialog<void>(
      context: page,
      builder: (_) => const AlertDialog(content: Text('Overlay')),
    );
    await tester.pumpAndSettle();
    final covered = ticks;
    await tester.pump(const Duration(minutes: 2));
    expect(ticks, covered);
    Navigator.of(page).pop();
    await tester.pumpAndSettle();
    expect(ticks, covered + 1);
  });

  testWidgets('a countdown that expires asleep gets one final refresh', (
    tester,
  ) async {
    var active = true;
    var ticks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _Clock(onTick: () => ticks++, enabled: () => active),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    active = false;
    final before = ticks;
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ticks, before + 1);
    await tester.pump(const Duration(minutes: 2));
    expect(ticks, before + 1);
  });
}

class _Clock extends StatefulWidget {
  const _Clock({required this.onTick, this.enabled});
  final VoidCallback onTick;
  final bool Function()? enabled;
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> with VisiblePeriodicRefresh<_Clock> {
  @override
  Duration get refreshInterval => const Duration(seconds: 10);
  @override
  bool get periodicRefreshEnabled => widget.enabled?.call() ?? true;
  @override
  void refreshVisibleContent() => widget.onTick();
  @override
  Widget build(BuildContext context) => const Text('Clock');
}

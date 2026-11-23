import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_daily_panel.dart';
import 'package:blood_pressure_app/features/nutrition/water_intake.dart';
import 'package:blood_pressure_app/features/nutrition/water_preferences_screen.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminder_screen.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/theme/app_fab_shape.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// The long press stays attached to the FAB while an overlay previews the amount.
/// No route is pushed during the gesture: Navigator would cancel its pointer.
class WaterActionButton extends ConsumerStatefulWidget {
  const WaterActionButton({
    super.key,
    required this.onPressed,
    required this.onLog,
  });
  final VoidCallback onPressed;
  final Future<void> Function(int) onLog;
  @override
  ConsumerState<WaterActionButton> createState() => _WaterActionButtonState();
}

class _WaterActionButtonState extends ConsumerState<WaterActionButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _targetKey = GlobalKey();
  final _targetLink = LayerLink();
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _foreground = true;
  bool _disposed = false;

  Rect? _sourceRect() {
    final box = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  Future<void> _openPanel(DateTime day) async {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.viewPaddingOf(context);
    final source = _sourceRect();
    final above = (source?.top ?? size.height) - safe.top - 24;
    final result = await showSafaehAnchored<String>(
      context: context,
      motion: SafaehAnchoredMotion.genie,
      link: _targetLink,
      sourceRect: source,
      sourceRectBuilder: _sourceRect,
      opensAbove: true,
      sourceShape: appFabShape,
      childBuilder: (context, progress) => SizedBox(
        width: math.min(360, math.max(0, size.width - 32)),
        child: WaterDailyPanel(
          day: day,
          maxHeight: math.max(120, math.min(size.height * .72, above)),
          elevation: safaehAnchoredElevation(progress),
          onLog: widget.onLog,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'edit') widget.onPressed();
    if (result == 'schedule') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WaterReminderScreen()),
      );
    } else if (result == 'settings') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WaterPreferencesScreen()),
      );
    }
  }

  void _syncWave() {
    final active =
        _foreground &&
        _overlay == null &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isCurrent != false;
    if (active) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  final _amount = ValueNotifier<int>(250);
  final _holding = ValueNotifier<bool>(false);
  OverlayEntry? _overlay;
  LocalHistoryEntry? _history;
  double _originY = 0;
  int _originAmount = 250;
  int _hapticBucket = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _close();
    _syncWave();
  }

  void _close() {
    final history = _history;
    _history = null;
    history?.remove();
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    _holding.value = false;
    if (!_disposed) _syncWave();
  }

  void _start(LongPressStartDetails details, WaterVessel vessel, int serving) {
    if (_overlay != null) return;
    _wave.stop();
    _originY = details.globalPosition.dy;
    _originAmount = serving;
    _amount.value = serving;
    _hapticBucket = serving ~/ 100;
    _holding.value = true;
    HapticFeedback.selectionClick();
    final range = ref.read(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final now = DateTime.now();
    final day = !now.isBefore(range.start) && !now.isAfter(range.end)
        ? now
        : range.end;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _overlay = OverlayEntry(
      builder: (overlayContext) => MediaQuery(
        data: MediaQuery.of(overlayContext)
            .copyWith(disableAnimations: reducedMotion),
        child: WaterAmountOverlay(
          entryDay: day,
          amount: _amount,
          holding: _holding,
          vessel: vessel,
          serving: serving,
          onCancel: _close,
          onLog: widget.onLog,
          onDone: _close,
          onSettings: () {
            _close();
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WaterPreferencesScreen(),
                ),
              );
            }
          },
        ),
      ),
    );
    _history = LocalHistoryEntry(onRemove: _close);
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _move(LongPressMoveUpdateDetails details) {
    if (_overlay == null || !_holding.value) return;
    // Relative movement avoids a jump to the finger's absolute screen position.
    final steps = ((_originY - details.globalPosition.dy) / 8).round();
    final next = (_originAmount + steps * 25)
        .clamp(25, math.max(2000, _originAmount * 2))
        .toInt();
    if (next == _amount.value) return;
    _amount.value = next;
    final bucket = next ~/ 100;
    if (bucket != _hapticBucket) {
      _hapticBucket = bucket;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _wave.dispose();
    _close();
    // Overlay widgets are removed on the next frame and may still read notifiers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amount.dispose();
      _holding.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvidersProvider);
    final bottle = ref.watch(waterBottlesProvider).defaultBottle;
    final vessel = bottle.vessel;
    final serving = bottle.ml;
    final day = ref.watch(waterEntryDayProvider);
    final intake = ref.watch(waterDayIntakeProvider(day));
    final total = intake.asData?.value;
    final target = ref.watch(settings.provider(waterDailyTargetSetting));
    final number = total == null
        ? '—'
        : NumberFormat.decimalPattern(context.locale.toString()).format(total);
    final fill = target > 0 && total != null
        ? (total / target).clamp(0.0, 1.0)
        : .12;
    return Semantics(
      label:
          '${nutritionText(context, 'addWater')}, $number ${nutritionText(context, 'ml')}, ${DateFormat.yMMMd(context.locale.toString()).format(day)}',
      value: target > 0
          ? '${nutritionText(context, 'waterDailyTarget')}: $target ${nutritionText(context, 'ml')}'
          : nutritionText(context, 'waterTargetUnset'),
      hint: nutritionText(context, 'waterHoldHint'),
      child: Listener(
        onPointerCancel: (_) => _close(),
        child: GestureDetector(
          onLongPressStart: (details) => _start(details, vessel, serving),
          onLongPressMoveUpdate: _move,
          onLongPressEnd: (_) {
            if (_overlay != null) {
              _holding.value = false;
            }
          },
          onLongPressCancel: _close,
          child: CompositedTransformTarget(
            key: _targetKey,
            link: _targetLink,
            child: SizedBox.square(
              dimension: 56,
              child: FloatingActionButton(
                key: const ValueKey('add-water'),
                heroTag: null,
                onPressed: () => _openPanel(day),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                shape: appFabShape,
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: appFabBorderRadius,
                    child: CustomPaint(
                      key: const ValueKey('water-fab-fill'),
                      painter: WaterFabWavePainter(
                        progress: fill,
                        motion: _wave,
                        color: waterBlue,
                      ),
                      child: SizedBox.expand(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            WaterVesselView(
                              vessel: vessel,
                              fill: fill,
                              size: 29,
                              motion: _wave,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$number ${nutritionText(context, 'ml')}',
                                  key: const ValueKey('water-fab-total'),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bounded, centered review surface. Release only changes from dragging to
/// review; the explicit log action is the only write and is guarded in flight.
class WaterAmountOverlay extends StatefulWidget {
  const WaterAmountOverlay({
    super.key,
    required this.entryDay,
    required this.amount,
    required this.holding,
    required this.vessel,
    required this.serving,
    required this.onCancel,
    required this.onLog,
    required this.onDone,
    required this.onSettings,
  });
  final DateTime entryDay;
  final ValueNotifier<int> amount;
  final ValueNotifier<bool> holding;
  final WaterVessel vessel;
  final int serving;
  final VoidCallback onCancel;
  final Future<void> Function(int) onLog;
  final VoidCallback onDone;
  final VoidCallback onSettings;
  @override
  State<WaterAmountOverlay> createState() => _WaterAmountOverlayState();
}

class _WaterAmountOverlayState extends State<WaterAmountOverlay> {
  bool _saving = false;
  bool _failed = false;
  Future<void> _save() async {
    if (_saving || widget.holding.value) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onLog(widget.amount.value);
      if (mounted) {
        widget.onDone();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => nutritionText(context, key);
    final scheme = Theme.of(context).colorScheme;
    final maxAmount = math.max(2000, widget.serving * 2);
    return BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: t('addWater'),
        explicitChildNodes: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: ColoredBox(
                      color: Color.alphaBlend(
                        waterBlue.withValues(alpha: .16),
                        Colors.black.withValues(alpha: .24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ModalBarrier(
              dismissible: !_saving,
              onDismiss: widget.onCancel,
              semanticsLabel: t('cancel'),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: widget.holding,
                      builder: (context, holding, _) => ValueListenableBuilder<int>(
                        valueListenable: widget.amount,
                        builder: (context, amount, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WaterPreviewSurface(
                              key: const ValueKey('water-amount-overlay'),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  16,
                                  28,
                                  24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedWaterVessel(
                                      vessel: widget.vessel,
                                      fill: amount / widget.serving,
                                      playing: holding,
                                      size:
                                          MediaQuery.sizeOf(context).height <
                                              500
                                          ? 100
                                          : 190,
                                    ),
                                    Semantics(
                                      liveRegion: !holding,
                                      child: Text(
                                        '$amount ${t('ml')}',
                                        key: const ValueKey(
                                          'water-drag-amount',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!holding) ...[
                              const SizedBox(height: 16),
                              Material(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat.yMMMd(
                                          context.locale.toString(),
                                        ).format(widget.entryDay),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: t('waterLess'),
                                            onPressed: _saving || amount <= 25
                                                ? null
                                                : () => widget.amount.value =
                                                      (amount - 25).clamp(
                                                        25,
                                                        maxAmount,
                                                      ),
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Expanded(
                                            child: Slider(
                                              label: '$amount ${t('ml')}',
                                              semanticFormatterCallback: (
                                                value,
                                              ) => '${value.round()} ${t('ml')}',
                                              value: amount.toDouble(),
                                              min: 25,
                                              max: maxAmount.toDouble(),
                                              divisions: (maxAmount - 25) ~/ 25,
                                              onChanged: _saving
                                                  ? null
                                                  : (value) =>
                                                        widget.amount.value =
                                                            value.round(),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: t('waterMore'),
                                            onPressed:
                                                _saving || amount >= maxAmount
                                                ? null
                                                : () => widget.amount.value =
                                                      (amount + 25).clamp(
                                                        25,
                                                        maxAmount,
                                                      ),
                                            icon: const Icon(Icons.add),
                                          ),
                                        ],
                                      ),
                                      if (_failed)
                                        Text(
                                          t('failed'),
                                          style: TextStyle(color: scheme.error),
                                        ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          key: const ValueKey('log-water-drag'),
                                          onPressed: _saving ? null : _save,
                                          icon: _saving
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.check),
                                          label: Text(
                                            '${t('waterLog')} · $amount ${t('ml')}',
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _saving
                                            ? null
                                            : widget.onCancel,
                                        child: Text(t('cancel')),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterPreviewSurface extends StatelessWidget {
  const _WaterPreviewSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .86, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: FocusScope(
      autofocus: true,
      child: Material(
        color: Color.alphaBlend(
          waterBlue.withValues(alpha: .13),
          Theme.of(context).colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(48),
        elevation: 4,
        child: child,
      ),
    ),
  );
}

/// Wave phase repaints only the FAB. The level is exclusively the day/target ratio.
class WaterFabWavePainter extends CustomPainter {
  WaterFabWavePainter({
    required this.progress,
    required this.motion,
    required this.color,
  }) : super(repaint: motion);
  final double progress;
  final Animation<double> motion;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final level = size.height * (1 - progress);
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 2) {
        path.lineTo(
          x,
          level +
              math.sin(
                    x / size.width * math.pi * 2 +
                        motion.value * math.pi * 2 +
                        layer * 2,
                  ) *
                  (progress >= 1 ? 0 : 2),
        );
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: layer == 0 ? .15 : .3),
      );
    }
  }

  @override
  bool shouldRepaint(WaterFabWavePainter old) =>
      old.progress != progress || old.motion != motion || old.color != color;
}

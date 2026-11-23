import 'dart:math' as math;

import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

const medicationWidgetRoute = '/medications/widget';
const _backgroundRoute = '/medications/widget/background';
const medicationWidgetWindowChannel = MethodChannel(
  'com.shenepoy.janan/widget_window',
);

/// Android supplies screen coordinates in logical pixels, including system bars.
Rect? medicationWidgetAnchor(Map<Object?, Object?>? launch) {
  final values = [
    'widgetLeft',
    'widgetTop',
    'widgetRight',
    'widgetBottom',
  ].map((key) => launch?[key]).toList();
  if (values.any((value) => value is! num || !value.isFinite)) return null;
  final rect = Rect.fromLTRB(
    (values[0] as num).toDouble(),
    (values[1] as num).toDouble(),
    (values[2] as num).toDouble(),
    (values[3] as num).toDouble(),
  );
  return rect.isEmpty ? null : rect;
}

/// No app shell is mounted behind the window: Android supplies the launcher.
List<Route<dynamic>> medicationWidgetInitialRoutes(
  String scheduleId, {
  Rect? anchor,
}) => [
  PageRouteBuilder<void>(
    settings: const RouteSettings(name: _backgroundRoute),
    opaque: false,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => SafaehNavigatorScope(
      useRootNavigator: false,
      child: _WidgetWindowLauncher(scheduleId: scheduleId, anchor: anchor),
    ),
  ),
];

class _WidgetWindowLauncher extends StatefulWidget {
  const _WidgetWindowLauncher({required this.scheduleId, this.anchor});
  final String scheduleId;
  final Rect? anchor;

  @override
  State<_WidgetWindowLauncher> createState() => _WidgetWindowLauncherState();
}

class _WidgetWindowLauncherState extends State<_WidgetWindowLauncher> {
  @override
  void initState() {
    super.initState();
    SafaehGenieShader.preload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMedicationWidgetPanel(
        context,
        widget.scheduleId,
        anchor: widget.anchor,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Reuse the medicine button's actual Safaeh motion, including its stationary
/// fading scrim. Android supplies only the source rectangle and transparent host.
Future<void> showMedicationWidgetPanel(
  BuildContext context,
  String scheduleId, {
  Rect? anchor,
}) async {
  // Animate the loaded card, as the in-app button does, rather than morphing
  // a spinner and replacing it with the full panel after the motion finishes.
  final providers = ProviderScope.containerOf(context, listen: false);
  final dataReady =
      Future.wait([
        providers.read(medicationWidgetOccurrencesProvider.future),
        providers.read(medicationSchedulesProvider.future),
      ]).then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          // The panel owns its retry UI when either repository fails.
        },
      );
  try {
    await medicationWidgetWindowChannel.invokeMethod<void>('waitForEntry');
  } on MissingPluginException {
    // Widget previews and other non-Android hosts have no native entry motion.
  } on PlatformException catch (error) {
    if (error.code == 'window_closed') return;
    rethrow;
  }
  await dataReady;
  if (!context.mounted) return;
  final media = MediaQuery.of(context);
  final padding = media.viewPadding;
  final source =
      anchor ?? Rect.fromLTWH(media.size.width / 2, padding.top + 16, 1, 1);
  final above =
      source.top - padding.top >
      media.size.height - padding.bottom - source.bottom;
  final availableHeight = above
      ? source.top - padding.top - 20
      : media.size.height - padding.bottom - source.bottom - 20;
  return showSafaehAnchored<void>(
    context: context,
    motion: SafaehAnchoredMotion.genie,
    sourceRect: source,
    opensAbove: above,
    sourceShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    maxCardWidth: 400,
    childBuilder: (context, progress) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(0, availableHeight)),
      child: MedicationWidgetDosePanel(
        scheduleId: scheduleId,
        elevation: safaehAnchoredElevation(progress),
      ),
    ),
  );
}

/// Replacing the panel with Calendar or an editor keeps that page open. Once
/// its stack is empty, hide the Android task so repeat taps reuse its engine.
class MedicationWidgetWindowObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name != _backgroundRoute) return;
    void dismiss() async {
      if (navigator == null || navigator!.canPop()) return;
      try {
        await medicationWidgetWindowChannel.invokeMethod<void>('dismiss');
      } on MissingPluginException {
        await SystemNavigator.pop();
      }
    }

    // Let Safaeh finish the reverse genie and scrim fade before hiding Android.
    if (route is TransitionRoute<dynamic>) {
      route.completed.then((_) => dismiss());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => dismiss());
    }
  }
}

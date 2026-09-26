import 'dart:async';
import 'dart:math' as math;

import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_popout.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Which shell FAB column to show.
enum NavigationActionKind {
  /// Pill check-in plus add blood pressure.
  bloodPressure,

  /// Add weight.
  weight,

  /// Open the export popout.
  export,
}

/// Floating action buttons pinned on the data tabs.
class NavigationActionButtons extends StatelessWidget {
  const NavigationActionButtons({
    super.key,
    this.kind = NavigationActionKind.bloodPressure,
  });

  /// Which buttons to show.
  final NavigationActionKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == NavigationActionKind.export) {
      return SizedBox.square(
        dimension: 56,
        child: FloatingActionButton(
          heroTag: 'floatingActionExport',
          tooltip: 'exportImport'.tr(),
          onPressed: () => showExportPopout(context),
          child: Icon(
            Icons.file_download_outlined,
            semanticLabel: 'export'.tr(),
          ),
        ),
      );
    }

    final isWeight = kind == NavigationActionKind.weight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isWeight) ...[
          _RecentMedicineFab(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoute.addMedicine.path),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox.square(
          dimension: 56,
          child: FloatingActionButton(
            heroTag: 'floatingActionAdd',
            tooltip: isWeight ? 'weight'.tr() : 'addMeasurement'.tr(),
            autofocus: true,
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(isWeight ? AppRoute.addWeight.path : AppRoute.add.path),
            child: Icon(Icons.add, semanticLabel: 'addMeasurement'.tr()),
          ),
        ),
      ],
    );
  }
}

class _RecentMedicineFab extends ConsumerStatefulWidget {
  const _RecentMedicineFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  ConsumerState<_RecentMedicineFab> createState() => _RecentMedicineFabState();
}

class _RecentMedicineFabState extends ConsumerState<_RecentMedicineFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuAnimationController;
  late final Animation<double> _menuOpacity;
  late final Animation<double> _menuScale;
  late final Animation<Offset> _menuSlide;
  final _buttonKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];
  List<MedicineIntake> _recent = const [];
  OverlayEntry? _menuEntry;
  int? _hoveredIndex;
  bool _isMenuDismissing = false;

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _menuOpacity = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _menuScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _menuAnimationController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _menuSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _menuAnimationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void dispose() {
    final entry = _menuEntry;
    _menuEntry = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
    _menuAnimationController.dispose();
    super.dispose();
  }

  Future<void> _openRecentMedicines() async {
    if (_menuEntry != null) return;
    List<MedicineIntake> recent;
    try {
      final intakeRepository = ref.read(medicineIntakeRepositoryProvider);
      recent = await intakeRepository.getMostRecentlyUsed(limit: 5);
      if (recent.length < 5) {
        final medicines = await ref
            .read(medicineRepositoryProvider)
            .getAllInCreationOrder();
        final options = [...recent];
        for (final medicine in medicines) {
          if (options.length == 5) break;
          if (recent.any((intake) => intake.medicine == medicine)) continue;
          final dose = medicine.dosis;
          if (dose == null) continue;
          options.add(
            MedicineIntake(
              time: DateTime.now(),
              medicine: medicine,
              dosis: dose,
            ),
          );
        }
        recent = options;
      }
    } catch (_) {
      if (mounted) widget.onPressed();
      return;
    }
    if (!mounted) return;
    if (recent.isEmpty) {
      widget.onPressed();
      return;
    }

    _recent = recent;
    _itemKeys
      ..clear()
      ..addAll(List.generate(recent.length, (_) => GlobalKey()));
    _hoveredIndex = null;

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    final buttonBox = _buttonKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || buttonBox is! RenderBox) return;

    final anchorTopLeft = overlayBox.globalToLocal(
      buttonBox.localToGlobal(Offset.zero),
    );
    final anchor = anchorTopLeft & buttonBox.size;
    final margin = math.min(16.0, overlayBox.size.width / 4);
    final menuWidth = math.min(260.0, overlayBox.size.width - margin * 2);
    final maxLeft = math.max(
      margin,
      overlayBox.size.width - menuWidth - margin,
    );
    final preferredLeft = anchor.center.dx >= overlayBox.size.width / 2
        ? anchor.right - menuWidth
        : anchor.left;
    final left = preferredLeft.clamp(margin, maxLeft);
    final bottom = (overlayBox.size.height - anchor.top + 8).clamp(
      0.0,
      overlayBox.size.height,
    );
    final maxHeight = math.max(1.0, anchor.top - margin - 8);

    _isMenuDismissing = false;
    _menuEntry = OverlayEntry(
      builder: (context) => IgnorePointer(
        ignoring: _isMenuDismissing,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_dismissMenu()),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              bottom: bottom,
              width: menuWidth,
              child: SlideTransition(
                position: _menuSlide,
                child: FadeTransition(
                  opacity: _menuOpacity,
                  child: ScaleTransition(
                    scale: _menuScale,
                    alignment: Alignment.bottomRight,
                    child: Material(
                      elevation: 8,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < _recent.length; i++)
                                _buildMedicineOption(context, i),
                            ],
                          ),
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
    overlay.insert(_menuEntry!);
    _menuAnimationController.forward(from: 0);
  }

  Widget _buildMedicineOption(BuildContext context, int index) {
    final intake = _recent[index];
    final theme = Theme.of(context);
    final isHovered = _hoveredIndex == index;
    final background = isHovered
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHigh;
    final foreground = isHovered
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final rawMedicineColor = intake.medicine.color;
    final medicineColor =
        rawMedicineColor == null ||
            rawMedicineColor == 0 ||
            rawMedicineColor == Colors.transparent.toARGB32()
        ? theme.colorScheme.primary
        : Color(rawMedicineColor);

    return SizedBox(
      key: _itemKeys[index],
      height: 64,
      child: InkWell(
        onTap: () => unawaited(_quickAddMedicine(intake)),
        child: Ink(
          color: background,
          child: Row(
            children: [
              Container(width: 4, height: 64, color: medicineColor),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: medicineColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medicineColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Symbols.pill,
                  fill: 1,
                  size: 19,
                  color: medicineColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intake.medicine.designation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                    Text(
                      formatMedicationDose(
                        intake.dosis.mg,
                        intake.medicine.unit,
                      ),
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  int? _medicineAt(Offset globalPosition) {
    for (var i = 0; i < _itemKeys.length; i++) {
      final object = _itemKeys[i].currentContext?.findRenderObject();
      if (object is! RenderBox || !object.hasSize) continue;
      final rect = object.localToGlobal(Offset.zero) & object.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    final index = _medicineAt(details.globalPosition);
    if (_hoveredIndex == index) return;
    _hoveredIndex = index;
    _menuEntry?.markNeedsBuild();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final index = _medicineAt(details.globalPosition) ?? _hoveredIndex;
    if (index == null || index < 0 || index >= _recent.length) return;
    unawaited(_quickAddMedicine(_recent[index]));
  }

  Future<void> _quickAddMedicine(MedicineIntake intake) async {
    _dismissMenu();
    final now = DateTime.now();
    await ref
        .read(medicineIntakeRepositoryProvider)
        .add(
          MedicineIntake(
            time: now,
            medicine: intake.medicine,
            dosis: intake.dosis,
          ),
        );
  }

  Future<void> _dismissMenu() async {
    final entry = _menuEntry;
    if (entry == null || _isMenuDismissing) return;
    _isMenuDismissing = true;
    entry.markNeedsBuild();
    try {
      await _menuAnimationController.reverse();
    } on TickerCanceled {
      return;
    }
    if (!mounted || !identical(_menuEntry, entry)) return;
    entry.remove();
    entry.dispose();
    _menuEntry = null;
    _recent = const [];
    _itemKeys.clear();
    _hoveredIndex = null;
    _isMenuDismissing = false;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('recentMedicineFabTouchTarget'),
    excludeFromSemantics: true,
    onTap: widget.onPressed,
    onLongPressStart: (_) => unawaited(_openRecentMedicines()),
    onLongPressMoveUpdate: _onLongPressMove,
    onLongPressEnd: _onLongPressEnd,
    child: AbsorbPointer(
      child: FloatingActionButton.small(
        key: _buttonKey,
        heroTag: 'floatingActionPill',
        tooltip: 'logMedication'.tr(),
        onPressed: widget.onPressed,
        child: Icon(Symbols.pill, fill: 1, semanticLabel: 'logMedication'.tr()),
      ),
    ),
  );
}

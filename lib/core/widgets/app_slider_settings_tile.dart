import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Modal slider with a preview that commits only when the user saves.
class AppSliderSettingsTile extends StatelessWidget {
  const AppSliderSettingsTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.leading,
    this.divisions,
    this.valueFormatter,
    this.dialogTitle,
    this.enabled = true,
  });
  final Widget title;
  final Widget? leading;
  final double value, min, max;
  final int? divisions;
  final String Function(double)? valueFormatter;
  final String? dialogTitle;
  final ValueChanged<double>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading,
    title: title,
    subtitle: Text(valueFormatter?.call(value) ?? '$value'),
    enabled: enabled,
    trailing: const Icon(Icons.tune),
    onTap: !enabled || onChanged == null
        ? null
        : () async {
            var draft = value.clamp(min, max);
            final result = await showResponsiveSheet<double>(
              context: context,
              title: dialogTitle,
              child: StatefulBuilder(
                builder: (context, update) => AppSheetBody(
                  footer: AppSheetAction(
                    label: 'btnSave'.tr(),
                    onPressed: () => Navigator.pop(context, draft),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueFormatter?.call(draft) ?? '$draft',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: draft,
                        min: min,
                        max: max,
                        divisions: divisions,
                        semanticFormatterCallback: valueFormatter,
                        onChanged: (value) => update(() => draft = value),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(valueFormatter?.call(min) ?? '$min'),
                          Text(valueFormatter?.call(max) ?? '$max'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (result != null && context.mounted) onChanged!(result);
          },
  );
}

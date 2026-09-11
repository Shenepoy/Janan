import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/horizontal_graph_line.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GraphMarkingsScreen extends ConsumerWidget {
  const GraphMarkingsScreen({super.key});

  // TODO: consider adding fullscreen dialog for adding markings (like medicine)
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // IMPORTANT: When adding more option, like vertical lines, add navigation bar
    return Scaffold(
      appBar: AppBar(forceMaterialTransparency: true),
      body: Center(
        child: Builder(
          builder: (context) {
            final settings = ref.watch(appSettingsProvider);
            final lines = settings.horizontalGraphLines.toList();
            return ListView.builder(
              itemCount: lines.length + 2, // support first and last row
              itemBuilder: (context, i) {
                if (i == 0) {
                  // first row
                  return Container(
                    padding: const EdgeInsets.all(10),
                    child: DefaultTextStyle.merge(
                      child: Text('horizontalLines'.tr()),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  );
                }
                if (i > lines.length) {
                  // last row
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: Text('addLine'.tr()),
                    onTap: () async {
                      final color = await showEdadatColorPickerDialog(context);
                      if (!context.mounted) return;
                      final height = await showNumberInputDialog(
                        context,
                        hintText: 'linePositionY'.tr(),
                      );

                      if (color == null || height == null) return;
                      lines.add(HorizontalGraphLine(color, height.round()));
                      await ref.writeHorizontalGraphLines(lines);
                    },
                  );
                }
                return ListTile(
                  leading: Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: lines[i - 1].color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(lines[i - 1].height.toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      lines.removeAt(i - 1);
                      await ref.writeHorizontalGraphLines(lines);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

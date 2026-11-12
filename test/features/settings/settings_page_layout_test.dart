import '../../util.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_column_management_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/features/settings/configure_warn_values_screen.dart';
import 'package:blood_pressure_app/features/settings/delete_data_screen.dart';
import 'package:blood_pressure_app/features/settings/range_limits_screen.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  final pages = <String, Widget>{
    'body profile': const BodyProfileScreen(),
    'ranges': const RangeLimitsScreen(),
    'warnings': const ConfigureWarnValuesScreen(),
    'bluetooth': const BluetoothDevicesScreen(),
    'delete data': const DeleteDataScreen(),
    'export columns': const ExportColumnsManagementScreen(),
    'help': const InformationScreen(
      title: 'Help',
      text: '# Format\n\nExample `yyyy-MM-dd`.',
    ),
  };
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [const Size(360, 800), const Size(1440, 900)]) {
      for (final dark in [false, true]) {
        for (final page in pages.entries) {
          testWidgets('${page.key} fits $size $locale dark=$dark', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await pumpApp(
              tester,
              await appBase(
                Builder(
                  builder: (context) => Theme(
                    data: dark
                        ? ThemeData.dark(useMaterial3: true)
                        : ThemeData.light(useMaterial3: true),
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(1.4)),
                      child: page.value,
                    ),
                  ),
                ),
                locale: locale,
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(SettingsPageFrame), findsOneWidget);
            expect(tester.takeException(), isNull);
            final frame = tester.widget<SettingsPageFrame>(
              find.byType(SettingsPageFrame),
            );
            final rect = tester.getRect(find.byWidget(frame.child));
            expect(rect.width, lessThanOrEqualTo(720));
            expect(rect.center.dx, closeTo(size.width / 2, 1));
            // Reach the bottom too: off-screen tiles must not overflow either.
            final scrollable = find.byType(Scrollable).first;
            await tester.drag(scrollable, const Offset(0, -1800));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}

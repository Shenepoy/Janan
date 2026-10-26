import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/features/settings/enter_timeformat_dialog.dart';
import 'package:blood_pressure_app/features/settings/version_screen.dart';
import 'package:blood_pressure_app/features/health_connect/health_connect_screen.dart';
import 'package:blood_pressure_app/screens/error_reporting_screen.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:blood_pressure_app/model/storage/export_csv_settings.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_converter.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_record_parsing_actor.dart';
import 'package:blood_pressure_app/features/export_import/ui/import_preview_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/ui/add_export_column_dialog.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_column_management_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_detail_screen.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_settings_screen.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/medications/medications_screen.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_screen.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/features/settings/configure_warn_values_screen.dart';
import 'package:blood_pressure_app/features/settings/delete_data_screen.dart';
import 'package:blood_pressure_app/features/settings/export_import_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_markings_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_screen.dart';
import 'package:blood_pressure_app/features/settings/range_limits_screen.dart';
import 'package:blood_pressure_app/features/settings/time_formats_reference_screen.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';
import 'package:blood_pressure_app/screens/weight_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

// Review captures are optional; normal test runs only check responsive layout.
const _capture = bool.fromEnvironment('capturePageReview');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Janan',
      packageName: 'com.shenepoy.janan',
      version: '26.10.9',
      buildNumber: '82',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (_) async => <String, Object?>{},
      )
      ..setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'),
        (call) async => call.method == 'getDatabasesPath'
            ? '/tmp/janan-page-review-databases'
            : null,
      );

    for (final family in {
      'Roboto': [
        'assets/fonts/NotoSans-Regular.ttf',
        'assets/fonts/NotoSans-Bold.ttf',
      ],
      'NotoSansTamil': [
        'assets/fonts/NotoSansTamil-Regular.ttf',
        'assets/fonts/NotoSansTamil-Bold.ttf',
      ],
      'NotoSansSC': ['assets/fonts/NotoSansSC.ttf'],
      'NotoSansJP': ['assets/fonts/NotoSansJP.ttf'],
      'NotoSansArabic': [
        'assets/fonts/NotoSansArabic-Regular.ttf',
        'assets/fonts/NotoSansArabic-Bold.ttf',
      ],
      'Ahem': [
        'assets/fonts/NotoSans-Regular.ttf',
        'assets/fonts/NotoSansArabic-Regular.ttf',
      ],
      'monospace': ['assets/fonts/NotoSans-Regular.ttf'],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final path in family.value) {
        loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('MaterialSymbolsOutlined')..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
          ),
        ))
        .load();
  });
  final at = DateTime.now().subtract(const Duration(days: 1));
  final record = BloodPressureRecord(
    time: at,
    sys: Pressure.mmHg(123),
    dia: Pressure.mmHg(78),
    pul: 65,
  );
  final weight = BodyweightRecord(time: at, weight: Weight.kg(75));
  final medicine = Medicine(
    designation: 'Amlodipine',
    dosis: Weight.mg(5),
    unit: MedicationUnit.mg,
  );
  final schedule = MedicationSchedule(
    id: 'review',
    medicineId: 'medicine',
    medicine: medicine,
    doseAmount: 5,
    doseUnit: MedicationUnit.mg,
    timeMinutes: const [480, 1200],
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
  );
  final pages = <String, Widget Function()>{
    'measurements': () => const AppHome(),
    'weight': () => const WeightScreen(),
    'statistics': () => const StatisticsScreen(),
    'settings': () => const SettingsPage(),
    'reading-editor': () => const AddEntryDialog(),
    'weight-editor': () => const AddEntryDialog(kind: AddEntryKind.weight),
    'dose-editor': () => const AddEntryDialog(kind: AddEntryKind.medicine),
    'reading-detail': () => MeasurementDetailScreen(
      entry: CombinedEntry(time: at, record: record),
    ),
    'weight-detail': () => WeightDetailScreen(record: weight),
    'today': () => const MedicationsScreen(),
    'reminders': () =>
        const MedicationsScreen(initialTab: MedicationTab.reminders),
    'medicines': () =>
        const MedicationsScreen(initialTab: MedicationTab.medicines),
    'reminder-editor': () => MedicationScheduleEditorScreen(initial: schedule),
    'medicine-editor': () => AddMedicationDialog(initialValue: medicine),
    'reminder-permissions': () => const MedicationReminderSettingsScreen(),
    'body-profile': () => const BodyProfileScreen(),
    'bluetooth-devices': () => const BluetoothDevicesScreen(),
    'chart-settings': () => const GraphScreen(),
    'warning-values': () => const ConfigureWarnValuesScreen(),
    'chart-markings': () => const GraphMarkingsScreen(),
    'range-limits': () => const RangeLimitsScreen(),
    'export-settings': () => const ExportImportScreen(),
    'export-columns': () => const ExportColumnsManagementScreen(),
    'export-column-editor': () => AddExportColumnDialog(
      initialColumn: UserColumn('review', 'systolic', r'$SYS'),
    ),
    'format-help': () => const TimeFormattingReferenceScreen(),
    'export-help': () => Builder(
      builder: (_) => InformationScreen(
        title: 'exportImport'.tr(),
        text: 'exportImportDocumentation'.tr(),
      ),
    ),
    'delete-data': () => const DeleteDataScreen(),
    'welcome': () => const OnboardingScreen(firstRun: false),
    'tour-add': () => const OnboardingScreen(firstRun: false),
    'tour-weight': () => const OnboardingScreen(firstRun: false),
    'tour-trends': () => const OnboardingScreen(firstRun: false),
    'tour-medicines': () => const OnboardingScreen(firstRun: false),
    'tour-features': () => const OnboardingScreen(firstRun: false),
    'tour-preferences': () => const OnboardingScreen(firstRun: false),
    'date-format-editor': () => const Scaffold(
      body: EnterTimeFormatDialog(initialValue: 'yyyy-MM-dd HH:mm'),
    ),
    'health-connect': () => const HealthConnectScreen(),
    'version': () => const VersionScreen(),
    'error-recovery': () => ErrorScreen(
      title: 'Example error',
      text: 'Example diagnostic details',
      debugInfo: PackageInfo(
        appName: 'Janan',
        packageName: 'com.shenepoy.janan',
        version: '26.10.9',
        buildNumber: '82',
      ),
    ),
    'licenses': () => const LicensePage(applicationName: 'Janan'),
    'export-pdf': () => const ExportImportScreen(),
    'export-database': () => const ExportImportScreen(),
    'export-field-help': () => Builder(
      builder: (_) => InformationScreen(
        title: 'fieldFormat'.tr(),
        text: 'exportFieldFormatDocumentation'.tr(),
      ),
    ),
    'import-preview': () => ImportPreviewDialog(
      bottomAppBar: false,
      initialActor: CsvRecordParsingActor(
        CsvConverter(
          CsvExportSettings(),
          ExportColumnsManager(),
          [],
          ExportSettings(),
        ),
        'timestampUnixMs,systolic,diastolic,pulse\n1703175193324,123,78,65',
      ),
      columnsManager: ExportColumnsManager(),
    ),
  };
  for (final locale in appSupportedLocales) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      for (final page in pages.entries) {
        testWidgets(
          '${translationFileTag(locale)} ${page.key} fits $size at 1.3x text',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final store = MockHealthStore()..medRepo = MockMedRepo([medicine]);
            await store.bpRepo.add(record);
            await store.weightRepo.add(weight);
            final doses = [
              DoseOccurrence(
                id: 'review-dose',
                schedule: schedule,
                scheduledAt: DateTime.now().add(const Duration(hours: 1)),
                status: 'pending',
              ),
            ];
            final boundary = GlobalKey();
            final app = await materialApp(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.3)),
                  child: Theme(
                    data: ThemeData(
                      fontFamily: 'Roboto',
                      fontFamilyFallback: [
                        'NotoSansArabic',
                        'NotoSansTamil',
                        if (locale.languageCode == 'ja') 'NotoSansJP',
                        'NotoSansSC',
                        if (locale.languageCode != 'ja') 'NotoSansJP',
                      ],
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFF00695C),
                      ),
                    ),
                    child: page.value(),
                  ),
                ),
              ),
              locale: locale,
              settings: TestSettingsSeed(
                language: locale,
                weightInput: true,
                bodyHeightCm: 175,
                birthYear: 1990,
                animationSpeed: 0,
              ),
              store: store,
              exportSettings: ExportSettings()
                ..exportFormat = switch (page.key) {
                  'export-pdf' => ExportFormat.pdf,
                  'export-database' => ExportFormat.db,
                  _ => ExportFormat.csv,
                },
              overrides: [
                medCacheProvider.overrideWithValue(
                  MedCache(store.medRepo, [medicine]),
                ),
                medicationScheduleRepositoryProvider.overrideWithValue(
                  _ReviewSchedules(schedule, doses),
                ),
                medicationSchedulesProvider.overrideWith(
                  (_) async => [schedule],
                ),
                homeMedicationOccurrencesProvider.overrideWith(
                  (_) async => doses,
                ),
                todayMedicationOccurrencesProvider.overrideWith(
                  (_) async => doses,
                ),
                medicationDayProvider.overrideWith((_, _) async => doses),
              ],
            );
            if (page.key == 'error-recovery') {
              loadTestTranslations(locale);
              Intl.defaultLocale = locale.toString();
            }
            await pumpApp(
              tester,
              RepaintBoundary(
                key: boundary,
                child: page.key == 'error-recovery' ? page.value() : app,
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            final tourPage = switch (page.key) {
              'tour-add' => 2,
              'tour-weight' => 3,
              'tour-trends' => 4,
              'tour-medicines' => 5,
              'tour-features' => 1,
              'tour-preferences' => 6,
              _ => 0,
            };
            for (var step = 0; step < tourPage; step++) {
              await tester.tap(find.byKey(const Key('onboarding-cta')));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
            expect(tester.takeException(), isNull);
            if (_capture && size.width == 390) {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await render.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'output/all-language-review/${translationFileTag(locale)}-${page.key}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          },
        );
      }
    }
  }
}

class _ReviewSchedules implements MedicationScheduleRepository {
  _ReviewSchedules(this.schedule, this.doses);
  final MedicationSchedule schedule;
  final List<DoseOccurrence> doses;
  @override
  Future<List<MedicationSchedule>> getAll() async => [schedule];
  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime day) async => doses;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected review operation: $invocation');
}

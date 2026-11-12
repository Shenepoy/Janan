import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Arabic floating snackbar does not move the end FAB', (
    tester,
  ) async {
    final fabKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            key: fabKey,
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          floatingActionButtonLocation: const SnackBarStableFabLocation(
            base: FloatingActionButtonLocation.endFloat,
          ),
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم الحفظ'))),
                child: const Text('إظهار'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('إظهار'))),
      TextDirection.rtl,
    );
    final fabPosition = tester.getTopLeft(find.byKey(fabKey));

    await tester.tap(find.text('إظهار'));
    await tester.pumpAndSettle();

    expect(find.text('تم الحفظ'), findsOneWidget);
    final fabRect = tester.getRect(find.byKey(fabKey));
    final snackBarRect = tester.getRect(find.byType(SnackBar));
    expect(fabRect.topLeft, fabPosition);
    expect(snackBarRect.bottom, lessThanOrEqualTo(fabRect.top));
    expect(tester.takeException(), isNull);
  });
}

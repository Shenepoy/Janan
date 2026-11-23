import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/blood_pressure_analyzer_test.dart';
import '../../util.dart';

void main() {
  for (final streamError in [false, true]) {
    testWidgets('comparison errors stay in the UI (stream: $streamError)', (
      tester,
    ) async {
      final repository = _CountingRepository();
      await repository.add(mockRecord(sys: 120, dia: 80, pul: 70));
      final store = MockHealthStore()..bpRepo = repository;
      await pumpApp(
        tester,
        await materialApp(const StatisticsScreen(), store: store),
      );
      await tester.pumpAndSettle();
      if (streamError) {
        repository.contr.addError(StateError('comparison updates failed'));
      } else {
        repository.failComparisons = true;
        await repository.add(mockRecord(sys: 130, dia: 85, pul: 75));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('comparison'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.contr.close();
    });
  }

  testWidgets(
    'statistics reuses its comparison query across presentation changes',
    (tester) async {
      final repository = _CountingRepository();
      await repository.add(mockRecord(sys: 120, dia: 80, pul: 70));
      final store = MockHealthStore()..bpRepo = repository;
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      await pumpApp(
        tester,
        await materialApp(
          ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, value, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(value)),
              child: child!,
            ),
            child: const StatisticsScreen(),
          ),
          store: store,
        ),
      );
      await tester.pumpAndSettle();
      final previous = repository.requests
          .where(
            (r) => r.end.isBefore(
              DateTime.now().subtract(const Duration(days: 6)),
            ),
          )
          .toList();
      expect(previous, hasLength(1));
      for (final value in [1.1, 1.0, 1.1]) {
        scale.value = value;
        await tester.pumpAndSettle();
      }
      expect(
        repository.requests.where((r) => r == previous.single),
        hasLength(1),
      );
      await repository.add(mockRecord(sys: 130, dia: 85, pul: 75));
      await tester.pumpAndSettle();
      expect(
        repository.requests.where((r) => r == previous.single),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.contr.close();
    },
  );
}

class _CountingRepository extends MockBloodPressureRepository {
  final requests = <DateRange>[];
  bool failComparisons = false;
  @override
  Future<List<BloodPressureRecord>> get(DateRange range) {
    requests.add(range);
    if (failComparisons &&
        range.end.isBefore(DateTime.now().subtract(const Duration(days: 6)))) {
      return Future.error(StateError('comparison query failed'));
    }
    return super.get(range);
  }
}

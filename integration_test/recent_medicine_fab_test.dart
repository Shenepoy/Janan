import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final recentIntakes = [
    for (var i = 1; i <= 6; i++)
      MedicineIntake(
        time: DateTime(2026, 9, 25).subtract(Duration(days: i)),
        medicine: Medicine(designation: 'Recent medicine $i'),
        dosis: Weight.mg(i * 5),
      ),
  ];

  testWidgets('long press shows five recent medicines and tap quick-adds', (
    tester,
  ) async {
    final repository = _FakeIntakeRepository(recentIntakes);
    await tester.pumpWidget(_testApp(repository));
    final touchTarget = find.byKey(
      const ValueKey('recentMedicineFabTouchTarget'),
    );

    await tester.longPress(touchTarget);
    await tester.pumpAndSettle();

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Recent medicine $i'), findsOneWidget);
    }
    expect(find.text('Recent medicine 6'), findsNothing);

    await tester.tap(find.text('Recent medicine 1'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repository.added, hasLength(1));
    expect(repository.added.single.medicine.designation, 'Recent medicine 1');
    expect(repository.added.single.dosis.mg, 5);
  });

  testWidgets('fills unused slots in medicine creation order', (tester) async {
    final repository = _FakeIntakeRepository(const []);
    final medicines = [
      Medicine(designation: 'Created first', dosis: Weight.mg(2)),
      Medicine(designation: 'Created second', dosis: Weight.mg(4)),
      Medicine(designation: 'Created third', dosis: Weight.mg(6)),
    ];
    await tester.pumpWidget(_testApp(repository, medicines: medicines));
    final touchTarget = find.byKey(
      const ValueKey('recentMedicineFabTouchTarget'),
    );

    await tester.longPress(touchTarget);
    await tester.pumpAndSettle();

    final first = find.text('Created first');
    final second = find.text('Created second');
    final third = find.text('Created third');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(third, findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(third).dy));

    await tester.tap(first);
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repository.added.single.medicine.designation, 'Created first');
    expect(repository.added.single.dosis.mg, 2);
  });

  testWidgets('dragging from the FAB to a recent medicine quick-adds', (
    tester,
  ) async {
    final repository = _FakeIntakeRepository(recentIntakes);
    await tester.pumpWidget(_testApp(repository));
    final touchTarget = find.byKey(
      const ValueKey('recentMedicineFabTouchTarget'),
    );
    final gesture = await tester.startGesture(tester.getCenter(touchTarget));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final option = find.text('Recent medicine 1');
    expect(option, findsOneWidget);
    await gesture.moveTo(tester.getCenter(option));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repository.added, hasLength(1));
    expect(repository.added.single.medicine.designation, 'Recent medicine 1');
    expect(repository.added.single.dosis.mg, 5);
  });
}

Widget _testApp(
  _FakeIntakeRepository repository, {
  List<Medicine> medicines = const [],
}) => ProviderScope(
  overrides: [
    medicineIntakeRepositoryProvider.overrideWithValue(repository),
    medicineRepositoryProvider.overrideWithValue(
      _FakeMedicineRepository(medicines),
    ),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: Text('Home')),
          Align(
            alignment: Alignment.bottomRight,
            child: NavigationActionButtons(),
          ),
        ],
      ),
    ),
  ),
);

class _FakeIntakeRepository extends MedicineIntakeRepository {
  _FakeIntakeRepository(this.recent);

  final List<MedicineIntake> recent;
  final List<MedicineIntake> added = [];

  @override
  Future<void> add(MedicineIntake value) async {
    added.add(value);
  }

  @override
  Future<List<MedicineIntake>> get(DateRange range) async => recent;

  @override
  Future<List<MedicineIntake>> getMostRecentlyUsed({int limit = 5}) async =>
      recent.take(limit).toList();

  @override
  Future<void> remove(MedicineIntake value) async {}

  @override
  Stream<MedicineIntake?> subscribe() => const Stream<MedicineIntake?>.empty();
}

class _FakeMedicineRepository extends MedicineRepository {
  _FakeMedicineRepository(this.medicines);

  final List<Medicine> medicines;

  @override
  Future<void> add(Medicine value) async {}

  @override
  Future<List<Medicine>> get(DateRange range) async => medicines;

  @override
  Future<List<Medicine>> getAll() async => medicines;

  @override
  Future<List<Medicine>> getAllInCreationOrder() async => medicines;

  @override
  Future<void> remove(Medicine value) async {}

  @override
  Stream<Medicine?> subscribe() => const Stream<Medicine?>.empty();
}

import 'package:blood_pressure_app/features/onboarding/onboarding_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  setUp(loadTestTranslations);

  testWidgets('a newly active scene animates then releases its ticker', (
    tester,
  ) async {
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 260,
              child: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, value, _) =>
                    OnboardingScene(page: 2, active: value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion shows the complete scene immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(
              child: SizedBox(
                width: 360,
                height: 260,
                child: OnboardingScene(page: 2, active: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the illustrated reading has a complete spoken equivalent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: OnboardingScene(page: 1, active: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Example only.*Systolic 120 mmHg.*Diastolic 80 mmHg.*Pulse 72 bpm',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

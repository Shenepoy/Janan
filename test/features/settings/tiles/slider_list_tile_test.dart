import 'package:blood_pressure_app/features/settings/tiles/slider_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

void main() {
  testWidgets('slider has a 48dp semantic target and accepts off-track taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      double? changed;
      await pumpApp(
        tester,
        await materialApp(
          SliderListTile(
            title: const Text('Repeat interval'),
            semanticLabel: 'Repeat interval',
            onChanged: (value) => changed = value,
            value: 1,
            min: 1,
            max: 120,
          ),
        ),
      );
      final slider = find.byType(Slider);
      expect(tester.getSize(slider).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(slider).rect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(tester.getCenter(slider) - const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(changed, greaterThan(1));
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('should not throw errors', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        SliderListTile(
          title: const Text('test title'),
          onChanged: (double newValue) {
            assert(false, 'should not be called');
          },
          value: 15,
          min: 1,
          max: 20,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await pumpApp(
      tester,
      await materialApp(
        SliderListTile(
          title: const Text('Very long title that could overflow'),
          onChanged: (double newValue) {
            assert(false, 'should not be called');
          },
          value: 15,
          min: 1,
          max: 20,
          stepSize: 0.001,
          leading: const Icon(Icons.add),
          trailing: const Icon(Icons.add),
          subtitle: const Text(
            'While sliders support subtitle widgets, they should not interfere with the slider!',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('should report value changes', (tester) async {
    int callCount = 0;
    await pumpApp(
      tester,
      await materialApp(
        SliderListTile(
          title: const Text('title'),
          onChanged: (double newValue) {
            callCount += 1;
            expect(newValue, 8);
          },
          value: 3,
          min: 1,
          max: 10,
          subtitle: const Text(
            'While sliders support subtitle widgets, they should not interfere with the slider!',
          ),
        ),
      ),
    );

    final topLeft = tester.getTopLeft(find.byType(Slider));
    final bottomRight = tester.getBottomRight(find.byType(Slider));

    final slider8Position = topLeft + ((bottomRight - topLeft) * 8 / 10);
    await tester.tapAt(slider8Position);
    await tester.pumpAndSettle();
    expect(callCount, 1);
  });
}

import 'dart:convert';

import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

class WaterBottle {
  const WaterBottle({
    required this.id,
    required this.vessel,
    required this.ml,
    this.name = '',
  });
  final String id;
  final WaterVessel vessel;
  final int ml;
  final String name;
  Map<String, Object> toJson() => {
    'id': id,
    'vessel': vessel.name,
    'ml': ml,
    'name': name,
  };
}

/// One atomic setting keeps the default and its capacity consistent on restore.
class WaterBottles {
  const WaterBottles(this.items, this.defaultId);
  final List<WaterBottle> items;
  final String defaultId;
  WaterBottle get defaultBottle =>
      items.firstWhere((b) => b.id == defaultId, orElse: () => items.first);
  String encode() => jsonEncode({
    'defaultId': defaultBottle.id,
    'items': items.map((b) => b.toJson()).toList(),
  });

  static WaterBottles decode(
    String raw, {
    required WaterVessel legacyVessel,
    required int legacyMl,
  }) {
    final fallback = WaterBottles([
      WaterBottle(
        id: 'default',
        vessel: legacyVessel,
        ml: legacyMl.clamp(25, 5000),
      ),
    ], 'default');
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = <WaterBottle>[];
      for (final value in json['items'] as List) {
        final item = value as Map<String, dynamic>;
        final id = item['id'] as String;
        final ml = item['ml'] as int;
        if (id.isEmpty ||
            items.any((b) => b.id == id) ||
            ml < 25 ||
            ml > 5000) {
          continue;
        }
        items.add(
          WaterBottle(
            id: id,
            vessel: waterVesselFromKey(item['vessel'] as String),
            ml: ml,
            name: (item['name'] as String? ?? '').trim(),
          ),
        );
        if (items.length == 4) break;
      }
      return items.isEmpty
          ? fallback
          : WaterBottles(
              List.unmodifiable(items),
              json['defaultId'] as String? ?? items.first.id,
            );
    } catch (_) {
      return fallback;
    }
  }
}

final waterBottlesProvider = Provider<WaterBottles>((ref) {
  final settings = ref.watch(settingsProvidersProvider);
  return WaterBottles.decode(
    ref.watch(settings.provider(waterBottlesSetting)),
    legacyVessel: waterVesselFromKey(
      ref.watch(settings.provider(waterVesselSetting)),
    ),
    legacyMl: ref.watch(settings.provider(waterServingSetting)),
  );
});

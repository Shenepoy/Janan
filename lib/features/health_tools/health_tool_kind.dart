import 'package:blood_pressure_app/features/health_tools/tool_field.dart';

enum HealthToolKind {
  foodDiary('food_diary', [
    ToolField('food', required: true),
    ToolField(
      'meal',
      required: true,
      options: ['breakfast', 'lunch', 'dinner', 'snack'],
    ),
    ToolField('portion'),
    ToolField('calories', numeric: true, minimum: 0, maximum: 100000),
    ToolField('protein', numeric: true, minimum: 0, maximum: 10000),
    ToolField('carbs', numeric: true, minimum: 0, maximum: 10000),
    ToolField('fat', numeric: true, minimum: 0, maximum: 10000),
    ToolField('note'),
  ]),
  waterDiary('water_diary', [
    ToolField(
      'water_ml',
      numeric: true,
      required: true,
      minimum: 1,
      maximum: 10000,
    ),
    ToolField('note'),
  ]),
  diaryContext('diary_context', [
    ToolField('symptom', required: true),
    ToolField('severity', numeric: true, minimum: 0, maximum: 10),
    ToolField('sleep_hours', numeric: true, minimum: 0, maximum: 24),
    ToolField('activity'),
    ToolField('caffeine'),
    ToolField('stress'),
    ToolField('circumstances'),
    ToolField('reading_id'),
  ]),
  refillAdjustment('refill_adjustments', [
    ToolField('med_id', required: true),
    ToolField('quantity', numeric: true, required: true),
    ToolField(
      'unit',
      required: true,
      options: ['mg', 'mcg', 'g', 'iu', 'tablet', 'ml'],
    ),
    ToolField('reason', required: true),
  ]),
  personalTarget('personal_targets', [
    ToolField(
      'metric',
      required: true,
      options: ['systolic', 'diastolic', 'pulse', 'weight'],
    ),
    ToolField(
      'unit',
      required: true,
      options: ['mmHg', 'kPa', 'bpm', 'kg', 'lb'],
    ),
    ToolField('minimum', numeric: true),
    ToolField('maximum', numeric: true),
    ToolField('source', required: true, options: ['personal', 'clinician']),
    ToolField('note'),
  ]),
  emergencyCard('emergency_cards', [
    ToolField('name'),
    ToolField('allergies'),
    ToolField('conditions'),
    ToolField('contact'),
    ToolField('medicine_ids_json'),
  ]),
  labObservation('lab_observations', [
    ToolField('name', required: true),
    ToolField('value', required: true),
    ToolField('unit'),
    ToolField('reference_range'),
    ToolField('source_hash'),
    ToolField('note'),
  ]),
  measurementSession('measurement_sessions', [
    ToolField('deadline_unix_s', numeric: true),
    ToolField('reading_ids_json'),
    ToolField('average_selected', numeric: true, minimum: 0, maximum: 1),
    ToolField('checklist_json'),
  ]);

  const HealthToolKind(this.table, this.fields);
  final String table;
  final List<ToolField> fields;
}

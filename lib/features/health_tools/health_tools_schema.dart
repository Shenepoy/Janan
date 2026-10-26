import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:powersync/powersync.dart';

final healthToolTables = [
  for (final kind in HealthToolKind.values)
    Table.localOnly(kind.table, [
      const Column.integer('timestamp_unix_s'),
      for (final field in kind.fields)
        if (field.numeric) Column.real(field.name) else Column.text(field.name),
    ]),
];

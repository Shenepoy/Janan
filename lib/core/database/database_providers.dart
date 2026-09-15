import 'package:blood_pressure_app/core/database/health_database.dart' show HealthDatabase;
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

/// Local-only PowerSync database. Override after [HealthDatabase.open].
@Riverpod(keepAlive: true)
PowerSyncDatabase healthDatabase(Ref ref) {
  throw UnimplementedError(
    'Override healthDatabaseProvider after HealthDatabase.open()',
  );
}

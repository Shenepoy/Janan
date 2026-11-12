import 'package:blood_pressure_app/core/repository/watch_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A builder that provides the contents of a repository.
class RepositoryBuilder<T, R extends Repository<T>> extends ConsumerWidget {
  /// Create a builder that provides the contents of a repository.
  const RepositoryBuilder({
    super.key,
    required this.rangeType,
    required this.onData,
  });

  /// Which measurements to load.
  final IntervalStoreManagerLocation rangeType;

  /// The build strategy once the data loaded.
  final Widget Function(BuildContext, List<T>) onData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = _watch<T>(ref, rangeType);
    if (async.hasError) {
      return Text('error'.tr(namedArgs: {'msg': '${async.error}'}));
    }
    final data = async.value;
    if (data == null) return Text('loading'.tr());
    return onData(context, data);
  }
}

AsyncValue<List<T>> _watch<T>(
  WidgetRef ref,
  IntervalStoreManagerLocation rangeType,
) {
  if (T == BloodPressureRecord) {
    return ref.watch(bloodPressureRecordsProvider(rangeType))
        as AsyncValue<List<T>>;
  }
  if (T == Note) {
    return ref.watch(notesProvider(rangeType)) as AsyncValue<List<T>>;
  }
  if (T == MedicineIntake) {
    return ref.watch(medicineIntakesProvider(rangeType)) as AsyncValue<List<T>>;
  }
  if (T == BodyweightRecord) {
    return ref.watch(bodyweightRecordsProvider(rangeType)) as AsyncValue<List<T>>;
  }
  if (T == Medicine) {
    return ref.watch(medicinesProvider) as AsyncValue<List<T>>;
  }
  throw StateError('No repository for $T');
}

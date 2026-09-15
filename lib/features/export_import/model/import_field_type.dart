import 'package:blood_pressure_app/features/export_import/model/record_formatter.dart';
import 'package:easy_localization/easy_localization.dart';

/// Type a [Formatter] can uses to indicate the kind of data returned.
enum RowDataFieldType {
  /// Guarantees [DateTime] is returned.
  timestamp,

  /// Guarantees [int] is returned.
  sys,

  /// Guarantees [int] is returned.
  dia,

  /// Guarantees [int] is returned.
  pul,

  /// Guarantees [String] is returned.
  notes,

  /// Guarantees that a [int] containing a [Color.toARGB32()] is returned.
  color,

  /// Guarantees [List<(String medicineDesignation, double dosisMg)>] is returned.
  intakes,

  /// Guarantees a [double] is parsed.
  weightKg;

  /// Select the matching string from `localizations`.
  String localize() => switch (this) {
    timestamp => 'timestamp'.tr(),
    sys => 'sysLong'.tr(),
    dia => 'diaLong'.tr(),
    pul => 'pulLong'.tr(),
    notes => 'notes'.tr(),
    color => 'color'.tr(),
    intakes => 'intakes'.tr(),
    weightKg => 'weight'.tr(),
  };
}

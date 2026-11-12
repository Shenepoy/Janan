import 'package:material_ui/material_ui.dart';

/// Theme-aware success / warning / danger colors.
///
/// Success follows [ColorScheme.primary] so a non-green scheme stays
/// consistent. Warning uses tertiary; danger uses error.
extension SafaehSemanticStatus on ColorScheme {
  Color get success => primary;
  Color get onSuccess => onPrimary;
  Color get warning => tertiary;
  Color get onWarning => onTertiary;
  Color get danger => error;
  Color get onDanger => onError;
}

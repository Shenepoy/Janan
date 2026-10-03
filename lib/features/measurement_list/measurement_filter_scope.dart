import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:flutter/widgets.dart';

/// Shared measurement-list filter for the shell app bar and the home list.
class MeasurementFilterController extends ChangeNotifier {
  MeasurementListFilter _value = MeasurementListFilter.all;

  MeasurementListFilter get value => _value;

  void select(MeasurementListFilter next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}

/// Provides [MeasurementFilterController] to the shell and its pages.
class MeasurementFilterScope extends InheritedNotifier<MeasurementFilterController> {
  const MeasurementFilterScope({
    super.key,
    required MeasurementFilterController controller,
    required super.child,
  }) : super(notifier: controller);

  static MeasurementFilterController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MeasurementFilterScope>()
        ?.notifier;
  }
}

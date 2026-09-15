import 'package:blood_pressure_app/domain/domain.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// In-memory cache for reading [MedicineRepository].
class MedCache with ChangeNotifier {
  MedCache(this._repo, List<Medicine> initialMeds) : _meds = initialMeds {
    _repo.subscribe().listen((_) async {
      _meds = await _repo.getAll();
      notifyListeners();
    });
  }

  final MedicineRepository _repo;

  List<Medicine> _meds;

  List<Medicine> get medications => UnmodifiableListView(_meds);

  bool get isEmpty => _meds.isEmpty;
}

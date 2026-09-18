import 'package:flutter/material.dart';

/// Tracks which list rows are selected.
class ListSelectionController<T> extends ChangeNotifier {
  final Set<T> _selected = {};

  /// True after the first row is selected.
  bool get isSelecting => _selected.isNotEmpty;

  /// Currently selected rows.
  Set<T> get selected => Set.unmodifiable(_selected);

  /// Number of selected rows.
  int get count => _selected.length;

  /// Whether [item] is selected.
  bool contains(T item) => _selected.contains(item);

  /// Add or remove [item].
  void toggle(T item) {
    if (!_selected.remove(item)) {
      _selected.add(item);
    }
    notifyListeners();
  }

  /// Select every item in [items].
  void selectAll(Iterable<T> items) {
    _selected
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  /// Leave selection mode.
  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}

/// Provides a [ListSelectionController] to descendant list rows.
class ListSelectionScope<T> extends InheritedNotifier<ListSelectionController<T>> {
  /// Expose [notifier] to descendants.
  const ListSelectionScope({
    super.key,
    required ListSelectionController<T> super.notifier,
    required super.child,
  });

  /// Current controller, if a host is present.
  static ListSelectionController<T>? maybeOf<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListSelectionScope<T>>()
          ?.notifier;
}

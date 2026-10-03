import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// A [ListTile] that allows choosing from a dropdown.
class DropDownListTile<T> extends StatefulWidget {
  /// Creates a list tile that allows choosing an item from a dropdown.
  ///
  /// Using this is equivalent to using a [ListTile] with a trailing [DropdownButton]. Please refer to those classes for
  /// argument definitions.
  const DropDownListTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.items,
    this.leading,
    this.subtitle,
    super.key,});

  /// Primary description of the tile.
  final Widget title;

  /// Secondary description below the title.
  final Widget? subtitle;

  /// A widget to display before the title.
  final Widget? leading;

  /// The value of the currently selected [DropdownMenuItem].
  final T? value;

  /// A list of items the user can select.
  final List<DropdownMenuItem<T>> items;

  /// Called when the selection changes.
  ///
  /// When null, the dropdown is disabled
  final void Function(T? value)? onChanged;

  @override
  State<DropDownListTile<T>> createState() => _DropDownListTileState<T>();
}

class _DropDownListTileState<T> extends State<DropDownListTile<T>> {
  @override
  Widget build(BuildContext context) {
    final current = widget.items.where((item) => item.value == widget.value);
    final label = current.isEmpty ? '—' : _dropdownItemLabel(current.first);
    return ListTile(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: widget.leading,
      enabled: widget.onChanged != null,
      trailing: IgnorePointer(
        ignoring: widget.onChanged == null,
        child: SafaehAnchoredDropdownChip<T?>(
          icon: Icons.unfold_more_rounded,
          label: label,
          selected: widget.value,
          options: [
            for (final item in widget.items)
              SafaehDropdownOption<T?>(
                value: item.value,
                label: _dropdownItemLabel(item),
              ),
          ],
          onSelected: (value) => widget.onChanged?.call(value),
        ),
      ),
    );
  }
}

String _dropdownItemLabel(DropdownMenuItem<dynamic> item) {
  final child = item.child;
  if (child is Text) {
    if (child.data != null) return child.data!;
    final span = child.textSpan;
    if (span != null) return span.toPlainText();
  }
  return '${item.value}';
}

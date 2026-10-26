/// A local form field and its storage validation rules.
class ToolField {
  const ToolField(
    this.name, {
    this.numeric = false,
    this.required = false,
    this.minimum,
    this.maximum,
    this.options = const [],
  });
  final String name;
  final bool numeric;
  final bool required;
  final double? minimum;
  final double? maximum;
  final List<String> options;
}

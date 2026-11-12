import 'package:material_ui/material_ui.dart';

/// Pre-formatted string with forced LTR so number/currency order stays
/// stable inside RTL UI shells.
///
/// Prefer this over a bare [Text] for money, codes, and other LTR-stable
/// strings. This file must not import `intl` (`TextDirection` would clash).
class SafaehLtrText extends StatelessWidget {
  const SafaehLtrText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      textDirection: TextDirection.ltr,
    );
  }
}

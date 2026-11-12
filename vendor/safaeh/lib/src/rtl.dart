import 'package:material_ui/material_ui.dart';

/// Material chevrons and back arrows already set [IconData.matchTextDirection].
/// Keep the LTR glyph. Swapping to the opposite icon in RTL mirrors twice.

/// Chevron pointing toward the end (forward / open).
IconData safaehChevronEnd(BuildContext context) => Icons.chevron_right;

/// Chevron pointing toward the start (back / collapse into the rail).
IconData safaehChevronStart(BuildContext context) => Icons.chevron_left;

/// Back arrow that points toward the start.
IconData safaehArrowBack(BuildContext context) => Icons.arrow_back;

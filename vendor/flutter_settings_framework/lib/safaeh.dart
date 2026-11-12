/// Opt-in Safaeh presentation helpers for the settings framework.
///
/// The main package entrypoint intentionally does not export this library.
/// Import it when the host app wants to use Safaeh's page-index, search,
/// adaptive modal chrome, or the 0.5 list/status/theme seams:
///
/// ```dart
/// import 'package:flutter_settings_framework/safaeh.dart';
/// ```
library;

export 'package:safaeh/safaeh.dart';
export 'src/ui/safaeh_page_index.dart';
export 'src/ui/safaeh_search.dart';

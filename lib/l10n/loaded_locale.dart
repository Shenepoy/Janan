import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Locale published with the completed translation load.
///
/// EasyLocalization's `locale` getter exposes its mutable controller immediately
/// when setLocale starts. A settings-driven rebuild can then load the old strings
/// under the new MaterialApp locale while the web asset is still downloading.
/// The inherited provider's snapshot changes only when the load is published.
Locale loadedAppLocale(BuildContext context) =>
    EasyLocalization.of(context)!.currentLocale!;

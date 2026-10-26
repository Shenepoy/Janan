import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional composition-owned settings. The standalone app has none.
final extraSettingsProvider = Provider<WidgetBuilder?>((ref) => null);

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional distribution-specific welcome copy. The offline app keeps its
/// translated default when no override is supplied.
final onboardingWelcomeBodyProvider = Provider<String Function(Locale locale)?>(
  (ref) => null,
);

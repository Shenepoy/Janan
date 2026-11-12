import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves local setup before optionally opening an account screen. The offline
/// distribution has no account step or authentication dependency.
typedef CompleteOnboarding = Future<void> Function({WidgetBuilder? nextPage});
typedef OnboardingConnectionBuilder = Widget Function(
  BuildContext context,
  CompleteOnboarding complete,
);

final onboardingConnectionProvider = Provider<OnboardingConnectionBuilder?>(
  (ref) => null,
);

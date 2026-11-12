import 'package:material_ui/material_ui.dart';

/// Shared error content for async / error states.
///
/// Hosts pass already-localized [title], [retryLabel], and [homeLabel].
/// Share / report buttons belong in [extraActions].
class SafaehErrorBody extends StatelessWidget {
  const SafaehErrorBody({
    super.key,
    required this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.homeLabel,
    this.onGoHome,
    this.extraActions = const <Widget>[],
  });

  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? homeLabel;
  final VoidCallback? onGoHome;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null && retryLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(retryLabel!),
            ),
          ],
          if (onGoHome != null && homeLabel != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onGoHome,
              icon: const Icon(Icons.home_outlined, size: 20),
              label: Text(homeLabel!),
            ),
          ],
          if (extraActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: extraActions,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/health_connect/sync_model.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SyncTile extends StatelessWidget {
  const SyncTile({super.key, required this.mdl, required this.disabled});

  final SyncModel mdl;

  final bool disabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: mdl,
    builder: (context, _) => ListTile(
      title: Text('syncNow'.tr()),
      subtitle: mdl.syncing
          ? LinearProgressIndicator(value: mdl.progress)
          : null,
      trailing: mdl.syncing
          ? const CircularProgressIndicator()
          : const Icon(Icons.sync),
      onTap: (disabled || mdl.syncing)
          ? null
          : () async {
              try {
                await mdl.sync();
              } catch (error, stack) {
                Log.warning(
                  'Health sync failed',
                  error: error,
                  stackTrace: stack,
                );
                if (context.mounted) context.showError('healthSyncFailed'.tr());
              }
            },
      enabled: !disabled,
    ),
  );
}

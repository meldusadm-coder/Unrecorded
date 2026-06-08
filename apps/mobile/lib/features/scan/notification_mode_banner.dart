import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/notification_status_provider.dart';
import 'scan_state.dart';

/// In-app summary of notification mode while protection is active.
class NotificationModeBanner extends ConsumerWidget {
  const NotificationModeBanner({super.key, required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.protectionRequested) return const SizedBox.shrink();

    final osEnabled = ref.watch(notificationsOsEnabledProvider);
    final riskAlerts = ref.watch(riskNotificationsEnabledProvider);

    return osEnabled.when(
      data: (notificationsOn) {
        return riskAlerts.when(
          data: (riskAlertsOn) {
            final lines = <String>[
              if (notificationsOn && riskAlertsOn)
                AppCopy.notificationModeRiskAlertsOn,
              if (notificationsOn) AppCopy.notificationModeProtectionStatusOn,
              if (!notificationsOn) AppCopy.notificationModeNotificationsOff,
              AppCopy.notificationModeScanningReliability,
            ];

            if (!notificationsOn) {
              return _Banner(
                text: lines.join(' '),
                actionLabel: 'Open settings',
                onAction: openAppSettings,
              );
            }

            return HelperText(text: lines.join(' '));
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

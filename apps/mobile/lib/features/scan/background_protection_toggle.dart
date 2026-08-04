import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../../services/protection_orchestrator_providers.dart';
import '../../services/protection_state.dart';

/// Compact Android background-mode preference toggle.
class BackgroundProtectionToggle extends ConsumerWidget {
  const BackgroundProtectionToggle({
    super.key,
    this.preferred,
    this.enabled,
    this.subtitle,
    this.visible = true,
  });

  /// When null, reads preference from the orchestrator tuple.
  final bool? preferred;
  final bool? enabled;
  final String? subtitle;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid || !visible) return const SizedBox.shrink();

    final orch = ref.watch(protectionOrchestratorProvider);
    final value =
        preferred ?? orch.lastConfirmedTuple?.backgroundModePreferred == true;
    final canToggle = enabled ?? !orch.isBusy;
    final theme = Theme.of(context);
    final statusLine = subtitle ??
        _defaultSubtitle(
          preferred: value,
          owner: orch.confirmedOwner,
          busy: orch.isBusy,
        );

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        AppCopy.backgroundProtectionTitle,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        statusLine,
        style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
      ),
      value: value,
      onChanged: !canToggle
          ? null
          : (next) async {
              final outcome = await ref
                  .read(protectionOrchestratorProvider.notifier)
                  .setBackgroundModePreferred(next);
              if (!context.mounted) return;
              if (outcome is ProtectionFailed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      outcome.issue.name == 'protocolPersistenceFailed'
                          ? 'Could not save background preference.'
                          : AppCopy.backgroundProtectionServiceStartFailed,
                    ),
                    action: const SnackBarAction(
                      label: 'Settings',
                      onPressed: openAppSettings,
                    ),
                  ),
                );
              }
            },
    );
  }

  static String _defaultSubtitle({
    required bool preferred,
    required ScannerOwner owner,
    required bool busy,
  }) {
    if (busy) return 'Switching…';
    if (owner == ScannerOwner.background) return 'Active in background';
    if (preferred) return 'Preferred for next time';
    return 'Preferred for next time';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import '../../services/background_protection_controller.dart';

/// Opt-in Android background protection toggle (off by default).
class BackgroundProtectionToggle extends ConsumerWidget {
  const BackgroundProtectionToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final bgState = ref.watch(backgroundProtectionControllerProvider);
    final controller =
        ref.read(backgroundProtectionControllerProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppCopy.backgroundProtectionTitle,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                AppCopy.backgroundProtectionSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              value: bgState.enabled && bgState.serviceRunning,
              onChanged: (enabled) async {
                if (enabled) {
                  final ok = await controller.enable();
                  if (!context.mounted) return;
                  if (!ok) {
                    final message = ref
                        .read(backgroundProtectionControllerProvider)
                        .lastFailureMessage;
                    if (message != null) {
                      final isNotificationDenied = message ==
                          AppCopy.backgroundProtectionNotificationRequired;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          action: isNotificationDenied
                              // ignore: prefer_const_constructors
                              ? SnackBarAction(
                                  label: 'Settings',
                                  onPressed: openAppSettings,
                                )
                              : null,
                        ),
                      );
                    }
                  }
                } else {
                  await controller.disable();
                }
              },
            ),
            if (bgState.enabled && bgState.serviceRunning) ...[
              const SizedBox(height: 4),
              Text(
                AppCopy.backgroundProtectionOnHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

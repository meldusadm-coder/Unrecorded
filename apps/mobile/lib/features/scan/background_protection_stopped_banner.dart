import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../../services/background_protection_controller.dart';

/// Shown when Android stopped background protection while user intent was ON.
class BackgroundProtectionStoppedBanner extends ConsumerWidget {
  const BackgroundProtectionStoppedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgState = ref.watch(backgroundProtectionControllerProvider);
    if (!bgState.showsStoppedByAndroidBanner) return const SizedBox.shrink();

    final controller =
        ref.read(backgroundProtectionControllerProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.backgroundProtectionStoppedByAndroid,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => controller.enable(),
                  child: const Text(AppCopy.backgroundProtectionRestart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

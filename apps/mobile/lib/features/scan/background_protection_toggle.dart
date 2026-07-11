import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import '../../services/background_protection_controller.dart';
import '../../services/scanner_provider.dart';

/// Opt-in Android background protection toggle (off by default).
class BackgroundProtectionToggle extends ConsumerStatefulWidget {
  const BackgroundProtectionToggle({super.key});

  @override
  ConsumerState<BackgroundProtectionToggle> createState() =>
      _BackgroundProtectionToggleState();
}

class _BackgroundProtectionToggleState
    extends ConsumerState<BackgroundProtectionToggle> {
  bool _showHelper = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(scanRuntimeProvider).isAndroid) {
      return const SizedBox.shrink();
    }

    final bgState = ref.watch(backgroundProtectionControllerProvider);
    final controller =
        ref.read(backgroundProtectionControllerProvider.notifier);
    final theme = Theme.of(context);
    final value = bgState.enabled && bgState.serviceRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: ExcludeSemantics(
                      child: Text(
                        AppCopy.backgroundProtectionTitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('background_protection_info'),
                    tooltip: 'Background protection details',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.info_outline, size: 18),
                    onPressed: () {
                      setState(() => _showHelper = !_showHelper);
                    },
                  ),
                ],
              ),
            ),
            Semantics(
              key: const Key('background_protection_switch_semantics'),
              label: AppCopy.backgroundProtectionTitle,
              button: true,
              toggled: value,
              hint: value
                  ? 'Tap to turn background protection off'
                  : 'Tap to turn background protection on',
              onTap: () {
                _setBackgroundProtection(
                  context: context,
                  ref: ref,
                  controller: controller,
                  enabled: !value,
                );
              },
              child: ExcludeSemantics(
                child: Switch(
                  key: const Key('background_protection_switch'),
                  value: value,
                  onChanged: (enabled) async {
                    await _setBackgroundProtection(
                      context: context,
                      ref: ref,
                      controller: controller,
                      enabled: enabled,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (_showHelper) ...[
          const SizedBox(height: 2),
          Text(
            AppCopy.backgroundProtectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        if (value) ...[
          const SizedBox(height: 4),
          Text(
            AppCopy.backgroundProtectionOnHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _setBackgroundProtection({
    required BuildContext context,
    required WidgetRef ref,
    required BackgroundProtectionController controller,
    required bool enabled,
  }) async {
    if (enabled) {
      final ok = await controller.enable();
      if (!context.mounted) return;
      if (!ok) {
        final message =
            ref.read(backgroundProtectionControllerProvider).lastFailureMessage;
        if (message != null) {
          final isNotificationDenied =
              message == AppCopy.backgroundProtectionNotificationRequired;
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
      return;
    }

    await controller.disable();
  }
}

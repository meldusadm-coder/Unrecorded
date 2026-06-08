import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/background_protection_controller.dart';
import '../../services/background_protection_snapshot.dart';
import '../../services/foreground_service_controller.dart';
import '../../services/risk_notification_service.dart';
import '../../services/scan_runtime.dart';
import '../../services/scanner_provider.dart';
import '../scan/scan_state.dart';

/// Debug-only controls for local UAT and BLE vs demo scanning.
class DebugTestingSection extends ConsumerStatefulWidget {
  const DebugTestingSection({super.key});

  @override
  ConsumerState<DebugTestingSection> createState() =>
      _DebugTestingSectionState();
}

class _DebugTestingSectionState extends ConsumerState<DebugTestingSection> {
  String _taskStatus = 'idle';
  late final ForegroundServiceController _fgs;

  @override
  void initState() {
    super.initState();
    _fgs = ref.read(foregroundServiceControllerProvider);
    _fgs.addDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    _fgs.removeDataCallback(_onTaskData);
    super.dispose();
  }

  void _onTaskData(Object data) {
    final snapshot = BackgroundProtectionSnapshot.fromJson(data);
    if (snapshot == null || !mounted) return;
    setState(() {
      _taskStatus = '${snapshot.status.name} • risk=${snapshot.riskLevel.name} '
          '• devices=${snapshot.possibleRiskCount + snapshot.otherNearbyCount}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();

    final config = ref.watch(scannerConfigProvider);
    if (config == null) {
      return const ListTile(
        title: Text('Developer testing'),
        subtitle: Text('Loading scanner configuration…'),
      );
    }

    final theme = Theme.of(context);
    final configController = ref.read(scannerConfigControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text('Developer testing', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Debug builds only. Demo mode uses scripted BLE data; Real BLE '
          'uses the device radio (physical Android recommended).',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 12),
        SegmentedButton<ScannerMode>(
          segments: const [
            ButtonSegment(
              value: ScannerMode.demo,
              label: Text('Demo'),
              icon: UnrecordedIcon(asset: UnrecordedIconAsset.scan, size: 18),
            ),
            ButtonSegment(
              value: ScannerMode.auto,
              label: Text('Real BLE'),
              icon: UnrecordedIcon(asset: UnrecordedIconAsset.device, size: 18),
            ),
          ],
          selected: {config.mode},
          onSelectionChanged: (selected) {
            configController.setMode(selected.first);
          },
        ),
        const SizedBox(height: 16),
        DropdownMenu<FakeDemoScenario>(
          key: ValueKey(config.scenario),
          label: const Text('Demo scenario'),
          enabled: config.mode == ScannerMode.demo,
          initialSelection: config.scenario,
          dropdownMenuEntries: FakeDemoScenario.values
              .map(
                (s) => DropdownMenuEntry(
                  value: s,
                  label: _scenarioLabel(s),
                ),
              )
              .toList(),
          onSelected: (scenario) {
            if (scenario != null) {
              configController.setScenario(scenario);
            }
          },
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () async {
            ref.read(scanControllerProvider.notifier).simulateHighRiskAlert();
            final scanState = ref.read(scanControllerProvider);
            if (scanState.status == ScanStatus.possibleRiskDetected) {
              await ref
                  .read(riskNotificationServiceProvider)
                  .showRiskAlertIfEnabled(riskLevel: scanState.riskLevel);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Sample alert shown on the scan screen. Use Demo → '
                    'Low risk only to avoid repeated emulator alerts.',
                  ),
                ),
              );
            }
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnrecordedIcon(asset: UnrecordedIconAsset.alert, size: 20),
              SizedBox(width: 8),
              Text('Simulate alert now'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await configController.clearOverrides();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reset to default scanner settings.'),
                ),
              );
            }
          },
          child: const Text('Reset scanner defaults'),
        ),
        const Divider(height: 32),
        Text(
          'Background service (developer UAT)',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Use the Background protection toggle above for the full flow. '
          'Task isolate status: $_taskStatus. Check logcat for '
          '[BackgroundScanTask] lines on a physical device.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              ref.watch(backgroundProtectionControllerProvider).serviceRunning
                  ? () => ref
                      .read(backgroundProtectionControllerProvider.notifier)
                      .requestTestRiskNotification()
                  : null,
          child: const Text('Post test risk notification (Phase 2a)'),
        ),
      ],
    );
  }

  static String _scenarioLabel(FakeDemoScenario scenario) {
    switch (scenario) {
      case FakeDemoScenario.random:
        return 'Random (legacy)';
      case FakeDemoScenario.low:
        return 'Low risk only';
      case FakeDemoScenario.medium:
        return 'Medium risk';
      case FakeDemoScenario.high:
        return 'High risk (UAT)';
    }
  }
}

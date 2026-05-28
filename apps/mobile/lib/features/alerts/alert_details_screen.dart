import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../router.dart';
import '../../services/scanner_provider.dart';
import '../scan/scan_state.dart';

/// Live alert context: risk level, possible devices, and reasons from the last scan.
class AlertDetailsScreen extends ConsumerWidget {
  const AlertDetailsScreen({super.key});

  static final _classifier = DeviceSignalClassifier();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final theme = Theme.of(context);
    final hasActiveAlert = state.status == ScanStatus.possibleRiskDetected;
    final topSignals = _classifier.topAlertSignals(state.signals);

    return Scaffold(
      appBar: AppBar(
        title: Text(hasActiveAlert ? 'Alert details' : 'Last assessment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiskBadge(level: state.riskLevel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActiveAlert
                            ? AppCopy.possibleRiskTitle
                            : 'Previous scan assessment',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActiveAlert
                            ? AppCopy.possibleRiskBody
                            : 'This is the most recent risk level from your last '
                                'protection scan. It is not proof of recording.',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.lastCheckedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                _lastCheckedLine(state.lastCheckedAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Possible device${topSignals.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (topSignals.isEmpty)
              Text(
                hasActiveAlert
                    ? 'No specific device name was identified. Nearby signals '
                        'may still match recording-device patterns.'
                    : 'Turn on protection to scan for nearby signals.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              )
            else
              ...topSignals.map((c) => _deviceTile(theme, c)),
            if (state.reasons.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Why this alert', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...state.reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(
                        child: Text(
                          r,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const HelperText(
              text: AppCopy.riskResultHelper,
              expandableDetail: PrivacyDisclaimer.detectionDisclaimer,
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const UnrecordedIcon(
                asset: UnrecordedIconAsset.info,
                size: 24,
              ),
              title: const Text('How detection works'),
              subtitle: const Text(
                'Risk levels, limitations, and what the app can detect',
              ),
              trailing: const UnrecordedListTrailing(),
              onTap: () => context.push(alertInfoRoute),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(ThemeData theme, ClassifiedSignal classified) {
    final signal = classified.signal;
    final name = signal.displayName ?? 'Unknown nearby device';
    final idLine = '${DeviceSignalClassifier.idLabel(signal.id)}: '
        '${DeviceSignalClassifier.formatId(signal.id)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      child: ListTile(
        leading: UnrecordedIcon(
          asset: classified.category ==
                  DeviceSignalCategory.possibleRecordingWearable
              ? UnrecordedIconAsset.glasses
              : UnrecordedIconAsset.device,
          size: 24,
          color: classified.category ==
                  DeviceSignalCategory.possibleRecordingWearable
              ? UnrecordedColors.warning
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(classified.typeLabel, style: theme.textTheme.bodySmall),
            if (classified.vendorHint != null) ...[
              const SizedBox(height: 2),
              Text(
                classified.vendorHint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(idLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              _proximityLabel(signal.rssi),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              signal.isConnectable
                  ? 'Connectable nearby'
                  : 'Connectable status unavailable',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _proximityLabel(int? rssi) {
    if (rssi == null) return 'Weak or uncertain signal';
    if (rssi >= -55) return 'Strong nearby signal';
    if (rssi >= -68) return 'Moderate nearby signal';
    return 'Weak or uncertain signal';
  }

  String _lastCheckedLine(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Last checked: just now';
    if (diff.inMinutes < 60) {
      return 'Last checked: ${diff.inMinutes} min ago';
    }
    return 'Last checked: ${diff.inHours} h ago';
  }
}

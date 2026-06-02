import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../router.dart';
import '../../services/scanner_provider.dart';
import '../../utils/time_format.dart';
import '../scan/signal_ui_model.dart';

/// Live alert context: risk level, possible devices, and evidence from the session.
class AlertDetailsScreen extends ConsumerWidget {
  const AlertDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final theme = Theme.of(context);
    final hasActiveAlert = state.showsRiskAlert;
    final devices = state.possibleRiskSignals;

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
            if (relativeLastChecked(state.lastCheckedAt) != null) ...[
              const SizedBox(height: 12),
              Text(
                relativeLastChecked(state.lastCheckedAt)!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Possible signal${devices.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              Text(
                hasActiveAlert
                    ? 'No specific device name was identified. Nearby signals '
                        'may still match recording-device patterns.'
                    : 'Turn on protection to scan for nearby signals.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              )
            else
              ...devices.map((s) => _deviceTile(theme, s)),
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
            const SizedBox(height: 12),
            Text(
              AppCopy.notProofOfRecording,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
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

  Widget _deviceTile(ThemeData theme, SignalUiModel signal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      child: ListTile(
        leading: const UnrecordedIcon(
          asset: UnrecordedIconAsset.glasses,
          size: 24,
          color: UnrecordedColors.warning,
        ),
        title: Text(
          signal.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(signal.categoryLabel, style: theme.textTheme.bodySmall),
            Text(signal.confidenceLabel, style: theme.textTheme.bodySmall),
            Text(signal.lastSeenLabel, style: theme.textTheme.bodySmall),
            Text(signal.signalStrengthLabel, style: theme.textTheme.bodySmall),
            if (signal.evidenceLabels.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...signal.evidenceLabels.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $e', style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

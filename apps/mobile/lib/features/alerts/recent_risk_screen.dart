import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/recent_risk_controller.dart';
import '../../utils/time_format.dart';

/// Lightweight explanation when live scan details are no longer available.
class RecentRiskScreen extends ConsumerWidget {
  const RecentRiskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentState = ref.watch(recentRiskControllerProvider);
    final event = recentState.event;
    final theme = Theme.of(context);

    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppCopy.recentRiskScreenTitle)),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No recent possible-risk reminder is active.'),
          ),
        ),
      );
    }

    final noticedText = relativeLastChecked(event.noticedAt);
    final reasonLabels = event.reasons
        .map(AppCopy.recentRiskReasonLabel)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text(AppCopy.recentRiskScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiskBadge(level: event.riskLevel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppCopy.recentRiskScreenTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppCopy.recentRiskScreenBody,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (noticedText != null) ...[
              const SizedBox(height: 12),
              Text(
                noticedText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Why this reminder', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (reasonLabels.isEmpty)
              Text(
                AppCopy.recentRiskGenericReason,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              )
            else
              ...reasonLabels.map(
                (label) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              AppCopy.recentRiskPrivacyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppCopy.notProofOfRecording,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(recentRiskControllerProvider.notifier).acknowledge();
                context.pop();
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

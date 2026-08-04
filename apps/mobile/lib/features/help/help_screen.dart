import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';
import '../scan/unrecorded_disclosure_sheet.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAndroid = ref.watch(scanRuntimeProvider).isAndroid;

    return Scaffold(
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BackButton(onPressed: () => context.pop()),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: AppLogo(size: 26),
            ),
          ],
        ),
        leadingWidth: 96,
        title: const Text('Help'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Text(
              'Example alert',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RiskAlertCard(
              title: AppCopy.alertCardTitle,
              body: AppCopy.alertCardBody,
              level: RiskLevel.high,
              isExample: true,
              onViewDetails: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This is only an example.'),
                  ),
                );
              },
              onDismiss: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This is only an example.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              AppCopy.alertExampleFooter,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const Divider(height: 24),
            const UnrecordedDisclosureAccordion(
              title: 'What does an alert mean?',
              body: 'A possible-risk alert means nearby Bluetooth signals '
                  'matched patterns associated with smart glasses or wearable '
                  'recording devices. It is a prompt to be more aware — not '
                  'proof that anyone is recording.',
            ),
            UnrecordedDisclosureAccordion(
              title: AppCopy.recentRiskMissedAlertTitle,
              body: AppCopy.recentRiskMissedAlertBody,
            ),
            const UnrecordedDisclosureAccordion(
              title: 'How detection works',
              body: 'Unrecorded compares nearby Bluetooth signals with known '
                  'wearable patterns, then shows a calm possible-risk warning '
                  'when indicators rise. Open How detection works from an '
                  'alert for risk levels and limitations.',
            ),
            const UnrecordedDisclosureAccordion(
              title: 'Why permissions are needed',
              body: AppCopy.permissionHelper,
            ),
            if (isAndroid)
              const UnrecordedDisclosureAccordion(
                title: 'Background protection and notification Stop',
                body: 'Background protection keeps checking nearby signals with '
                    'a persistent notification while Android allows it. '
                    'Notification Stop turns protection off and keeps your '
                    'preferred background mode for next time. Android or '
                    'battery settings may still interrupt background work — '
                    'uninterrupted operation is not guaranteed.',
              ),
            if (isAndroid)
              UnrecordedDisclosureAccordion(
                title: AppCopy.widgetHelpTitle,
                body: '${AppCopy.widgetHelpBody}\n\n'
                    '${AppCopy.widgetHelpLimitations}',
              ),
            UnrecordedDisclosureAccordion(
              title: AppCopy.notificationsHelpTitle,
              body: AppCopy.notificationsHelpBody,
            ),
            const Divider(height: 24),
            ListTile(
              key: const Key('help_feedback_tile'),
              contentPadding: EdgeInsets.zero,
              leading: const UnrecordedIcon(
                asset: UnrecordedIconAsset.share,
                size: 24,
              ),
              title: const Text(FeedbackCopy.sendFeedbackButton),
              subtitle: const Text(
                'Tell us what was confusing, broken, or missing',
              ),
              trailing: const UnrecordedListTrailing(),
              onTap: () => context.push('/feedback'),
            ),
            const SizedBox(height: 16),
            Text(
              PrivacyDisclaimer.detectionDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

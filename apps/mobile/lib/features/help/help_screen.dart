import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';

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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Text(
              'Example alert',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const HelperText(
              text: 'If Unrecorded detects a possible recording risk nearby, '
                  'you may see an alert like this:',
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            const HelperText(text: AppCopy.alertExampleFooter),
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
              onTap: () => context.push('/alert-info'),
            ),
            if (isAndroid) ...[
              const Divider(height: 32),
              Row(
                children: [
                  const UnrecordedIcon(
                    asset: UnrecordedIconAsset.widgetIcon,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppCopy.widgetHelpTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const HelperText(text: AppCopy.widgetHelpBody),
              const SizedBox(height: 8),
              const HelperText(text: AppCopy.widgetHelpLimitations),
            ],
            const Divider(height: 32),
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
            const Divider(height: 32),
            const HelperText(
              text: PrivacyDisclaimer.detectionDisclaimer,
            ),
          ],
        ),
      ),
    );
  }
}

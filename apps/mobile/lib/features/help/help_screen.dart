import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/ads_service.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(size: 26),
        ),
        title: const Text('Help'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  Text(
                    'Example alert',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const HelperText(
                    text:
                        'If Unrecorded detects a possible recording risk nearby, '
                        'you may see an alert like this:',
                  ),
                  const SizedBox(height: 12),
                  RiskAlertCard(
                    title: AppCopy.alertCardTitle,
                    body: AppCopy.alertCardBody,
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
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/alert-info'),
                  ),
                  const Divider(height: 32),
                  const HelperText(
                    text: PrivacyDisclaimer.detectionDisclaimer,
                  ),
                ],
              ),
            ),
            BottomAdSlot(
              onRemoveAdsTap: () => context.push('/remove-ads'),
              child: ref.watch(bannerAdWidgetProvider),
            ),
          ],
        ),
      ),
    );
  }
}

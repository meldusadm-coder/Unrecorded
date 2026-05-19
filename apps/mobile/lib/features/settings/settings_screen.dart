import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/ads_service.dart';
import '../../services/entitlement_service.dart';
import 'debug_testing_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final adsRemoved = ref.watch(adsRemovedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const PrivacyNoticeCard(
                    text: PrivacyDisclaimer.privacyModel,
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 20),
                  _tile(
                    theme,
                    icon: Icons.smartphone_outlined,
                    title: 'Local-first',
                    subtitle:
                        'All scanning happens on your device. Nothing is uploaded.',
                  ),
                  _tile(
                    theme,
                    icon: Icons.person_off_outlined,
                    title: 'No account required',
                    subtitle:
                        'Unrecorded works without sign-up, login, or any account.',
                  ),
                  _tile(
                    theme,
                    icon: Icons.cloud_off_outlined,
                    title: 'No cloud upload',
                    subtitle:
                        'Scan data stays on your device unless you choose otherwise.',
                  ),
                  _tile(
                    theme,
                    icon: Icons.analytics_outlined,
                    title: 'No analytics or tracking',
                    subtitle:
                        'The app does not include analytics or telemetry.',
                  ),
                  _tile(
                    theme,
                    icon: Icons.ads_click_outlined,
                    title: 'Small bottom ads',
                    subtitle: adsRemoved
                        ? 'Ads are removed on this device. Thank you for your support.'
                        : 'Optional banner ads may appear. Scan data is never sent to ad networks.',
                  ),
                  const DebugTestingSection(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.volunteer_activism_outlined,
                        color: theme.colorScheme.primary,),
                    title: const Text(AppCopy.removeAdsTitle),
                    subtitle: const Text(AppCopy.removeAdsBody),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/remove-ads'),
                  ),
                  const Divider(height: 32),
                  Text('Funding', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    PrivacyDisclaimer.fundingNote,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Unrecorded v0.1.0',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (!adsRemoved)
              BottomAdSlot(
                onRemoveAdsTap: () => context.push('/remove-ads'),
                child: ref.watch(bannerAdWidgetProvider),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}

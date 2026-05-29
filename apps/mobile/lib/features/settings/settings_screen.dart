import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/ad_consent_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/notification_prefs.dart';
import '../../services/notification_risk_threshold.dart';
import '../../services/risk_notification_service.dart';
import 'debug_testing_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _riskNotificationsEnabled;
  NotificationRiskThreshold? _notificationRiskThreshold;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await NotificationPrefs.load();
    if (!mounted) return;
    setState(() {
      _riskNotificationsEnabled = prefs.riskNotificationsEnabled;
      _notificationRiskThreshold = prefs.notificationRiskThreshold;
    });
  }

  Future<void> _setRiskNotifications(bool enabled) async {
    if (enabled) {
      final granted = await ref
          .read(riskNotificationServiceProvider)
          .requestPermissionIfNeeded();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission was denied. Enable it in system settings.',
            ),
          ),
        );
        return;
      }
    } else {
      await ref.read(riskNotificationServiceProvider).cancelRiskAlert();
    }

    final prefs = await NotificationPrefs.load();
    await prefs.setRiskNotificationsEnabled(enabled);
    if (!mounted) return;
    setState(() => _riskNotificationsEnabled = enabled);
  }

  Future<void> _setNotificationRiskThreshold(
    NotificationRiskThreshold? threshold,
  ) async {
    if (threshold == null) return;
    final prefs = await NotificationPrefs.load();
    await prefs.setNotificationRiskThreshold(threshold);
    if (!mounted) return;
    setState(() => _notificationRiskThreshold = threshold);
  }

  Future<void> _showAdPrivacyChoices() async {
    try {
      await ref.read(adConsentServiceProvider).showPrivacyOptionsForm();
      ref.invalidate(adPrivacyOptionsRequiredProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad privacy choices are unavailable right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final privacyOptionsRequired = ref.watch(adPrivacyOptionsRequiredProvider);

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
        title: const Text('Settings & Privacy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Text('Alerts', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppCopy.riskNotificationsTitle),
              subtitle: const Text(AppCopy.riskNotificationsSubtitle),
              value: _riskNotificationsEnabled ?? false,
              onChanged: _riskNotificationsEnabled == null
                  ? null
                  : _setRiskNotifications,
            ),
            if (_riskNotificationsEnabled == true) ...[
              const SizedBox(height: 8),
              DropdownMenu<NotificationRiskThreshold>(
                key: ValueKey(_notificationRiskThreshold),
                label: const Text(AppCopy.riskNotificationLevelTitle),
                helperText: AppCopy.riskNotificationLevelSubtitle,
                initialSelection: _notificationRiskThreshold,
                enabled: _notificationRiskThreshold != null,
                trailingIcon: UnrecordedIcon(
                  asset: UnrecordedIconAsset.more,
                  size: 24,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                dropdownMenuEntries: NotificationRiskThreshold.values
                    .map(
                      (t) => DropdownMenuEntry(
                        value: t,
                        label: t.label,
                        leadingIcon: UnrecordedIcon(
                          asset: t == NotificationRiskThreshold.highOnly
                              ? UnrecordedIconAsset.riskHigh
                              : UnrecordedIconAsset.riskMedium,
                          size: 22,
                        ),
                      ),
                    )
                    .toList(),
                onSelected: _setNotificationRiskThreshold,
              ),
            ],
            const SizedBox(height: 24),
            PrivacyNoticeCard(
              text: PrivacyDisclaimer.privacyModel,
              icon: UnrecordedIcon(
                asset: UnrecordedIconAsset.privacy,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _tile(
              theme,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.device,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: 'Local-first',
              subtitle:
                  'All scanning happens on your device. Nothing is uploaded.',
            ),
            _tile(
              theme,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.protection,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: 'No account required',
              subtitle:
                  'Unrecorded works without sign-up, login, or any account.',
            ),
            _tile(
              theme,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.privacy,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: 'No cloud upload',
              subtitle:
                  'Scan data stays on your device unless you choose otherwise.',
            ),
            _tile(
              theme,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.info,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: 'No analytics or tracking',
              subtitle: 'The app does not include analytics or telemetry.',
            ),
            _tile(
              theme,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.widgetIcon,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: 'Small bottom ads',
              subtitle: adsRemoved
                  ? 'Ads are removed on this device. Thank you for your support.'
                  : 'Optional banner ads may appear. Scan data is never sent to ad networks.',
            ),
            privacyOptionsRequired.maybeWhen(
              data: (required) {
                if (!required) return const SizedBox.shrink();
                return ListTile(
                  key: const Key('ad_privacy_choices_tile'),
                  contentPadding: EdgeInsets.zero,
                  leading: UnrecordedIcon(
                    asset: UnrecordedIconAsset.privacy,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(AppCopy.adPrivacyChoicesTitle),
                  subtitle: const Text(AppCopy.adPrivacyChoicesSubtitle),
                  trailing: const UnrecordedListTrailing(),
                  onTap: _showAdPrivacyChoices,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppLogo(size: 24),
              title: const Text(AppCopy.removeAdsTitle),
              subtitle: const Text(AppCopy.removeAdsBody),
              trailing: const UnrecordedListTrailing(),
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
            const DebugTestingSection(),
            const SizedBox(height: 16),
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
    );
  }

  Widget _tile(
    ThemeData theme, {
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}

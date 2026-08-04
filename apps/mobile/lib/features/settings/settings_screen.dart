import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';
import '../../copy/monetisation_copy.dart';
import '../../services/app_version.dart';
import '../../services/ad_consent_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/notification_prefs.dart';
import '../../services/recent_risk_controller.dart';
import '../../services/notification_risk_threshold.dart';
import '../../services/notification_status_provider.dart';
import '../../services/risk_notification_service.dart';
import '../scan/background_protection_toggle.dart';
import '../scan/unrecorded_disclosure_sheet.dart';
import 'debug_testing_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _riskNotificationsEnabled;
  NotificationRiskThreshold? _notificationRiskThreshold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshNotificationOsStatus(ref);
    }
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
          // SnackBarAction callback prevents a fully const SnackBar.
          // ignore: prefer_const_constructors
          SnackBar(
            content: const Text(AppCopy.notificationPermissionDeniedHelper),
            // ignore: prefer_const_constructors
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        refreshNotificationOsStatus(ref);
        return;
      }
    } else {
      await ref.read(riskNotificationServiceProvider).cancelRiskAlert();
    }

    final prefs = await NotificationPrefs.load();
    await prefs.setRiskNotificationsEnabled(enabled);
    ref.invalidate(riskNotificationsEnabledProvider);
    refreshNotificationOsStatus(ref);
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

  void _openPrivacySheet() {
    final adsRemoved = ref.read(adsRemovedProvider);
    UnrecordedDisclosureSheet.show(
      context: context,
      title: 'Privacy & data',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• All scanning happens on your device. Nothing is uploaded.'),
          const SizedBox(height: 8),
          const Text(
            '• Unrecorded works without sign-up, login, or any account.',
          ),
          const SizedBox(height: 8),
          const Text(
            '• Scan data stays on your device unless you choose otherwise.',
          ),
          const SizedBox(height: 8),
          const Text('• The app does not include analytics or telemetry.'),
          const SizedBox(height: 8),
          Text(
            adsRemoved
                ? '• Ads are removed on this device. Thank you for your support.'
                : '• Optional banner ads may appear. Scan data is never sent to ad networks.',
          ),
          const SizedBox(height: 12),
          const Text(PrivacyDisclaimer.privacyModel),
        ],
      ),
    );
  }

  void _openFundingSheet() {
    UnrecordedDisclosureSheet.show(
      context: context,
      title: PrivacyDisclaimer.fundingNoteShort,
      body: const Text(PrivacyDisclaimer.fundingNote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final privacyOptionsRequired = ref.watch(adPrivacyOptionsRequiredProvider);
    final recentRiskWindow = ref.watch(recentRiskControllerProvider).window;

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
        bottom: false,
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
            UnrecordedDisclosureSheet.trigger(
              context: context,
              label: 'How notification alerts work',
              sheetTitle: 'How notification alerts work',
              sheetBody: const Text(AppCopy.notificationsHelpBody),
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
            const SizedBox(height: 16),
            DropdownMenu<RecentRiskWindow>(
              key: ValueKey(recentRiskWindow),
              label: const Text(AppCopy.recentRiskReminderTitle),
              helperText: AppCopy.recentRiskReminderSubtitle,
              initialSelection: recentRiskWindow,
              trailingIcon: UnrecordedIcon(
                asset: UnrecordedIconAsset.more,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              dropdownMenuEntries: RecentRiskWindow.values
                  .map(
                    (window) => DropdownMenuEntry(
                      value: window,
                      label: window.label,
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                if (value == null) return;
                ref
                    .read(recentRiskControllerProvider.notifier)
                    .setWindow(value);
              },
            ),
            UnrecordedDisclosureSheet.trigger(
              context: context,
              label: 'How recent reminders work',
              sheetTitle: 'How recent reminders work',
              sheetBody: const Text(AppCopy.recentRiskReminderHelp),
            ),
            const SizedBox(height: 16),
            const BackgroundProtectionToggle(),
            const SizedBox(height: 24),
            PrivacyNoticeCard(
              text: PrivacyDisclaimer.privacyModelConcise,
              icon: UnrecordedIcon(
                asset: UnrecordedIconAsset.privacy,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              actionLabel: 'Privacy & data',
              onAction: _openPrivacySheet,
            ),
            ListTile(
              key: const Key('privacy_data_tile'),
              contentPadding: EdgeInsets.zero,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.privacy,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Privacy & data'),
              subtitle: const Text('Local-first scanning, no account, no cloud'),
              trailing: const UnrecordedListTrailing(),
              onTap: _openPrivacySheet,
            ),
            if (adsRemoved)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UnrecordedIcon(
                  asset: UnrecordedIconAsset.widgetIcon,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Ads removed'),
                subtitle: const Text(
                  'Ads are removed on this device. Thank you for your support.',
                ),
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
                  title: const Text(MonetisationCopy.adPrivacyChoicesTitle),
                  subtitle:
                      const Text(MonetisationCopy.adPrivacyChoicesSubtitle),
                  trailing: const UnrecordedListTrailing(),
                  onTap: _showAdPrivacyChoices,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppLogo(size: 24),
              title: const Text(MonetisationCopy.removeAdsTitle),
              subtitle: const Text(MonetisationCopy.removeAdsBody),
              trailing: const UnrecordedListTrailing(),
              onTap: () => context.push('/remove-ads'),
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(PrivacyDisclaimer.fundingNoteShort),
              subtitle: const Text('Ads and optional support purchases'),
              trailing: const UnrecordedListTrailing(),
              onTap: _openFundingSheet,
            ),
            const SizedBox(height: 16),
            Text('Feedback', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            ListTile(
              key: const Key('settings_feedback_tile'),
              contentPadding: EdgeInsets.zero,
              leading: UnrecordedIcon(
                asset: UnrecordedIconAsset.share,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              title: const Text(FeedbackCopy.sendFeedbackButton),
              subtitle: const Text(
                'Report bugs, confusion, or suggestions',
              ),
              trailing: const UnrecordedListTrailing(),
              onTap: () => context.push('/feedback'),
            ),
            const SizedBox(height: 32),
            const DebugTestingSection(),
            const SizedBox(height: 16),
            ref.watch(appVersionLabelProvider).when(
                  data: (label) => Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

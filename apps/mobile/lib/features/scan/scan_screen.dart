import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';
import '../../router.dart';
import '../../services/notification_status_provider.dart';
import '../../services/protection_orchestrator_providers.dart';
import '../../services/scanner_provider.dart';
import '../../services/widget_sync_service.dart';
import 'background_protection_toggle.dart';
import 'main_screen_ui_state.dart';
import 'protection_hero.dart';
import 'signal_ui_model.dart';
import 'status_notice_row.dart';
import 'unrecorded_disclosure_sheet.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  Widget build(BuildContext context) {
    ref.watch(widgetSyncServiceProvider);

    final ui = ref.watch(mainScreenUiStateProvider);
    final scan = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(size: 26),
        ),
        title: const Text('Unrecorded'),
        actions: [
          IconButton(
            icon:
                const UnrecordedIcon(asset: UnrecordedIconAsset.help, size: 24),
            tooltip: 'Help',
            onPressed: () => context.push('/help'),
          ),
          IconButton(
            key: const Key('settings_button'),
            icon: const UnrecordedIcon(
              asset: UnrecordedIconAsset.settings,
              size: 24,
            ),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            ProtectionHero(
              state: ui,
              onViewDetails: ui.showLiveAlertActions
                  ? () => context.push('/alert-details')
                  : null,
              onDismiss: ui.showLiveAlertActions
                  ? () => controller.dismissRiskAlert()
                  : null,
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: ui.primaryLabel,
              icon: ui.primaryAction == MainScreenPrimaryAction.turnOn
                  ? const AppLogo(size: 24, forColoredBackground: true)
                  : const UnrecordedStatusIcon(
                      asset: UnrecordedStatusAsset.scanningPaused,
                      size: 24,
                    ),
              tone: ui.primaryAction == MainScreenPrimaryAction.turnOn
                  ? PrimaryActionTone.primary
                  : PrimaryActionTone.danger,
              onPressed: ui.primaryEnabled ? () => _handlePrimary(ui) : null,
            ),
            if (ui.secondaryAction != null && ui.secondaryLabel != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _handleAction(ui.secondaryAction!),
                  child: Text(ui.secondaryLabel!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            BackgroundProtectionToggle(
              preferred: ui.backgroundPreferred,
              enabled: ui.backgroundToggleEnabled,
              subtitle: ui.backgroundToggleSubtitle,
              visible:
                  ui.backgroundToggleStatus != BackgroundToggleStatus.hidden,
            ),
            if (ui.noticeKind != null && ui.noticeMessage != null) ...[
              const SizedBox(height: 12),
              StatusNoticeRow(
                message: ui.noticeMessage!,
                actionLabel: ui.noticeActionLabel,
                onAction: ui.noticeActionLabel == null
                    ? null
                    : () => _handleNoticeAction(ui),
              ),
            ],
            const SizedBox(height: 8),
            UnrecordedDisclosureSheet.trigger(
              context: context,
              key: const Key('scan_privacy_disclosure'),
              label: 'Scan data stays on this device · How it works',
              sheetTitle: 'How protection works',
              sheetBody: const Text(
                '${AppCopy.scanHelper}\n\n'
                '${PrivacyDisclaimer.detectionDisclaimer}',
              ),
            ),
            if (scan.possibleRiskSignals.isNotEmpty ||
                scan.otherNearbySignals.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NearbySignalsDisclosure(
                riskSignals: scan.possibleRiskSignals,
                otherSignals: scan.otherNearbySignals,
                hasLiveAlert: ui.showLiveAlertActions,
              ),
            ],
            if (ui.showFeedbackLink) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  key: const Key('scan_feedback_link'),
                  onPressed: () => context.push('/feedback'),
                  child: const Text(FeedbackCopy.sendFeedbackButton),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrimary(MainScreenUiState ui) {
    return _handleAction(ui.primaryAction);
  }

  Future<void> _handleNoticeAction(MainScreenUiState ui) async {
    switch (ui.noticeKind) {
      case MainScreenNoticeKind.notificationsOff:
        await openAppSettings();
      case MainScreenNoticeKind.recentRisk:
        if (mounted) await context.push(recentRiskRoute);
      case MainScreenNoticeKind.recovery:
        await _handleAction(ui.primaryAction);
      case null:
        break;
    }
  }

  Future<void> _handleAction(MainScreenPrimaryAction action) async {
    final orch = ref.read(protectionOrchestratorProvider.notifier);
    switch (action) {
      case MainScreenPrimaryAction.turnOn:
        await orch.turnProtectionOn();
      case MainScreenPrimaryAction.turnOff:
      case MainScreenPrimaryAction.turningOff:
        await orch.stopAllProtection();
      case MainScreenPrimaryAction.tryAgain:
        await orch.retryCurrentIssue();
      case MainScreenPrimaryAction.openSettings:
        await openAppSettings();
      case MainScreenPrimaryAction.restartBackground:
        await orch.setBackgroundModePreferred(true);
        await orch.turnProtectionOn();
    }
  }
}

class _NearbySignalsDisclosure extends StatelessWidget {
  const _NearbySignalsDisclosure({
    required this.riskSignals,
    required this.otherSignals,
    required this.hasLiveAlert,
  });

  final List<SignalUiModel> riskSignals;
  final List<SignalUiModel> otherSignals;
  final bool hasLiveAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = riskSignals.length + otherSignals.length;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Nearby signals ($count)',
        style: theme.textTheme.titleSmall,
      ),
      subtitle: const Text('Collapsed details — tap to expand'),
      children: [
        if (riskSignals.isEmpty && hasLiveAlert)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Summary only is available here. Open alert details for more.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ...riskSignals.map(_signalCard),
        if (otherSignals.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Other nearby devices (${otherSignals.length})',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 4),
          ...otherSignals.map(_signalCard),
        ],
      ],
    );
  }

  Widget _signalCard(SignalUiModel signal) {
    final evidence = signal.evidenceLabels.isNotEmpty
        ? signal.evidenceLabels.first
        : signal.confidenceLabel;
    return SignalCard(
      name: signal.title,
      typeLabel: '${signal.categoryLabel} · $evidence',
      subtitle: '${signal.lastSeenLabel} · ${signal.signalStrengthLabel}',
      isSuspicious: signal.contributesToRisk,
    );
  }
}

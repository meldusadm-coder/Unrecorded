import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';
import 'background_protection_stopped_banner.dart';
import 'background_protection_toggle.dart';
import 'notification_mode_banner.dart';
import '../../router.dart';
import '../../services/background_protection_controller.dart';
import '../../services/recent_risk_controller.dart';
import '../../services/recent_risk_visibility.dart';
import '../../services/scanner_provider.dart';
import '../../services/widget_sync_service.dart';
import 'protection_screen_ui_state.dart';
import 'scan_state.dart';
import 'signal_ui_model.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSyncServiceProvider);

    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final uiState = ProtectionScreenUiState.fromScanState(state);
    final recentRisk = ref.watch(recentRiskVisibleProvider);
    final recentWindow = ref.watch(recentRiskControllerProvider).window.label;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(size: 26),
        ),
        title: const Text('Unrecorded'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            if (state.isDemoMode && state.protectionRequested)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: Text(AppCopy.demoModeBanner),
                  leading: Icon(Icons.science_outlined),
                  actions: [SizedBox.shrink()],
                ),
              ),
            _ProtectionControl(
              state: state,
              uiState: uiState,
              onPressed: uiState.primaryActionEnabled
                  ? () => _toggleProtection(ref, state, controller)
                  : null,
            ),
            const SizedBox(height: 12),
            _StatusArea(
              uiState: uiState,
              state: state,
              onAction: () {
                if (state.status == ScanStatus.possibleRiskDetected) {
                  context.push('/alert-details');
                } else if (state.isBlocked) {
                  openAppSettings();
                } else if (state.status == ScanStatus.error) {
                  controller.startProtection();
                }
              },
              onDismissAlert: controller.dismissRiskAlert,
            ),
            const SizedBox(height: 12),
            const BackgroundProtectionToggle(),
            const SizedBox(height: 12),
            const BackgroundProtectionStoppedBanner(),
            if (recentRisk != null) ...[
              const SizedBox(height: 16),
              RiskAlertCard(
                title: AppCopy.recentRiskCardTitle,
                body: AppCopy.recentRiskCardBody(recentWindow),
                onViewDetails: () => context.push(recentRiskRoute),
                onDismiss: () => ref
                    .read(recentRiskControllerProvider.notifier)
                    .acknowledge(),
              ),
            ],
            const SizedBox(height: 16),
            _MoreInformationAndSettings(state: state),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProtection(
    WidgetRef ref,
    ScanState state,
    ScanController controller,
  ) async {
    if (state.protectionActive) {
      final bgOwns =
          ref.read(backgroundProtectionControllerProvider).ownsScanning;
      if (bgOwns) {
        await ref
            .read(backgroundProtectionControllerProvider.notifier)
            .disable();
      }
      await controller.pauseProtection();
    } else {
      await controller.startProtection();
    }
  }
}

class _ProtectionControl extends StatelessWidget {
  const _ProtectionControl({
    required this.state,
    required this.uiState,
    required this.onPressed,
  });

  final ScanState state;
  final ProtectionScreenUiState uiState;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = state.protectionActive || state.status == ScanStatus.starting;
    final foreground = isOn
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onPrimaryContainer;
    final background =
        isOn ? theme.colorScheme.primary : theme.colorScheme.primaryContainer;

    return Semantics(
      key: const Key('main_protection_control_semantics'),
      button: onPressed != null,
      enabled: onPressed != null,
      toggled: isOn,
      label: uiState.controlLabel,
      hint: onPressed == null
          ? null
          : (isOn ? 'Tap to turn protection off' : 'Tap to turn protection on'),
      child: SizedBox(
        width: double.infinity,
        height: 96,
        child: FilledButton(
          key: const Key('main_protection_control'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isOn ? Icons.shield : Icons.shield_outlined, size: 28),
              const SizedBox(height: 6),
              Text(uiState.controlLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusArea extends StatelessWidget {
  const _StatusArea({
    required this.uiState,
    required this.state,
    required this.onAction,
    required this.onDismissAlert,
  });

  final ProtectionScreenUiState uiState;
  final ScanState state;
  final VoidCallback onAction;
  final VoidCallback onDismissAlert;

  @override
  Widget build(BuildContext context) {
    if (uiState.showsRiskAlert) {
      return RiskAlertCard(
        title: uiState.statusTitle,
        body: '${uiState.supportingText}\n\n${uiState.protectionLine}.',
        level: state.riskLevel,
        onViewDetails: onAction,
        onDismiss: onDismissAlert,
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          uiState.statusTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          uiState.supportingText,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (uiState.actionLabel != null) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(uiState.actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _MoreInformationAndSettings extends StatelessWidget {
  const _MoreInformationAndSettings({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('More information and settings'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        const HelperText(
          text: AppCopy.scanHelper,
          expandableDetail: PrivacyDisclaimer.detectionDisclaimer,
        ),
        const SizedBox(height: 12),
        NotificationModeBanner(state: state),
        if (state.possibleRiskSignals.isNotEmpty ||
            state.otherNearbySignals.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NearbySignalsSection(
            riskSignals: state.possibleRiskSignals,
            otherSignals: state.otherNearbySignals,
          ),
        ],
        if (state.reasons.isNotEmpty && state.protectionActive) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Why this risk level?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          ...state.reasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(r)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppCopy.notProofOfRecording,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const UnrecordedIcon(
            asset: UnrecordedIconAsset.help,
            size: 22,
          ),
          title: const Text('How detection works'),
          onTap: () => context.push('/help'),
        ),
        ListTile(
          key: const Key('settings_button'),
          contentPadding: EdgeInsets.zero,
          leading: const UnrecordedIcon(
            asset: UnrecordedIconAsset.settings,
            size: 22,
          ),
          title: const Text('Settings & privacy'),
          onTap: () => context.push('/settings'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const UnrecordedIcon(
            asset: UnrecordedIconAsset.more,
            size: 22,
          ),
          title: const Text('Remove ads'),
          onTap: () => context.push('/remove-ads'),
        ),
        ListTile(
          key: const Key('scan_feedback_link'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.feedback_outlined),
          title: const Text(FeedbackCopy.sendFeedbackButton),
          onTap: () => context.push('/feedback'),
        ),
      ],
    );
  }
}

class _NearbySignalsSection extends StatelessWidget {
  const _NearbySignalsSection({
    required this.riskSignals,
    required this.otherSignals,
  });

  final List<SignalUiModel> riskSignals;
  final List<SignalUiModel> otherSignals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (riskSignals.isNotEmpty) ...[
          Text(
            'Possible risk signals (${riskSignals.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...riskSignals.map(_signalCard),
        ],
        if (otherSignals.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Other nearby devices (${otherSignals.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: const Text('Unlikely to be recording wearables'),
            children: otherSignals.map(_signalCard).toList(),
          ),
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

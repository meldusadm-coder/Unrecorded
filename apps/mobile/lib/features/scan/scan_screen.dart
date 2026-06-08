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
import '../../services/background_protection_controller.dart';
import '../../services/scanner_provider.dart';
import '../../services/widget_sync_service.dart';
import '../../utils/time_format.dart';
import 'scan_state.dart';
import 'signal_ui_model.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSyncServiceProvider);

    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final showAlert = state.showsRiskAlert;
    final topRisk = state.possibleRiskSignals.isEmpty
        ? null
        : state.possibleRiskSignals.first;

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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            ScanStatusCard(
              icon: _iconWidgetForStatus(state.status, state.riskLevel),
              title: _titleForStatus(state),
              subtitle: _subtitleForStatus(state),
              lastCheckedText: _lastCheckedText(state),
            ),
            const SizedBox(height: 12),
            const BackgroundProtectionStoppedBanner(),
            NotificationModeBanner(state: state),
            const SizedBox(height: 12),
            const BackgroundProtectionToggle(),
            const SizedBox(height: 12),
            const HelperText(
              text: AppCopy.scanHelper,
              expandableDetail: PrivacyDisclaimer.detectionDisclaimer,
            ),
            const SizedBox(height: 12),
            _buildNextStep(context, state, controller),
            if (showAlert) ...[
              const SizedBox(height: 16),
              if (topRisk != null)
                Card(
                  child: ListTile(
                    title: Text(topRisk.title),
                    subtitle: Text(topRisk.categoryLabel),
                    trailing: const Text('View details'),
                    onTap: () => context.push('/alert-details'),
                  ),
                ),
              RiskAlertCard(
                title: AppCopy.alertCardTitle,
                body: AppCopy.alertCardBody,
                level: state.riskLevel,
                onViewDetails: () => context.push('/alert-details'),
                onDismiss: () => controller.dismissRiskAlert(),
              ),
              const SizedBox(height: 8),
              const HelperText(text: AppCopy.riskResultHelper),
            ],
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: state.protectionActive
                  ? AppCopy.pauseProtection
                  : AppCopy.turnOnProtection,
              icon: state.protectionActive
                  ? const UnrecordedStatusIcon(
                      asset: UnrecordedStatusAsset.scanningPaused,
                      size: 24,
                    )
                  : const AppLogo(size: 24, forColoredBackground: true),
              color: state.protectionActive ? UnrecordedColors.danger : null,
              onPressed: () async {
                if (state.protectionActive) {
                  final bgOwns = ref
                      .read(backgroundProtectionControllerProvider)
                      .ownsScanning;
                  if (bgOwns) {
                    await ref
                        .read(backgroundProtectionControllerProvider.notifier)
                        .disable();
                  }
                  await controller.pauseProtection();
                } else {
                  await controller.startProtection();
                }
              },
            ),
            if (state.possibleRiskSignals.isNotEmpty ||
                state.otherNearbySignals.isNotEmpty) ...[
              const SizedBox(height: 20),
              _NearbySignalsSection(
                riskSignals: state.possibleRiskSignals,
                otherSignals: state.otherNearbySignals,
              ),
            ],
            if (state.reasons.isNotEmpty && state.protectionActive) ...[
              const SizedBox(height: 16),
              Text(
                'Why this risk level?',
                style: Theme.of(context).textTheme.titleSmall,
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
              Text(
                AppCopy.notProofOfRecording,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (!showAlert) ...[
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

  Widget _buildNextStep(
    BuildContext context,
    ScanState state,
    ScanController controller,
  ) {
    if (state.isBlocked) {
      return NextStepBanner(
        message: state.statusMessage ?? AppCopy.permissionHelper,
        actionLabel: 'Open settings',
        onAction: openAppSettings,
      );
    }
    switch (state.status) {
      case ScanStatus.possibleRiskDetected:
        return const NextStepBanner(
          message:
              'Stay aware of your surroundings. You can view details or dismiss the alert.',
        );
      case ScanStatus.confirmingRisk:
        return const NextStepBanner(message: AppCopy.confirmingRisk);
      case ScanStatus.scanning:
        if (!state.hasElevatedRisk) {
          return const NextStepBanner(message: AppCopy.noRiskWhileScanning);
        }
        return const SizedBox.shrink();
      case ScanStatus.resting:
        return const NextStepBanner(message: AppCopy.scanResting);
      case ScanStatus.error:
        return NextStepBanner(
          message: state.statusMessage ?? 'Something went wrong.',
          actionLabel: 'Try again',
          onAction: controller.startProtection,
        );
      case ScanStatus.idle:
      case ScanStatus.paused:
        return const NextStepBanner(
          message:
              'Turn on protection to keep checking for possible recording risk.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _titleForStatus(ScanState state) {
    switch (state.status) {
      case ScanStatus.idle:
        return 'Protection is off';
      case ScanStatus.starting:
        return 'Starting protection…';
      case ScanStatus.scanning:
        return AppCopy.scanningActive;
      case ScanStatus.resting:
        return AppCopy.scanResting;
      case ScanStatus.confirmingRisk:
        return AppCopy.confirmingRisk;
      case ScanStatus.possibleRiskDetected:
        return AppCopy.possibleRiskTitle;
      case ScanStatus.paused:
        return 'Protection paused';
      case ScanStatus.error:
        return 'Scan issue';
      case ScanStatus.permissionDenied:
      case ScanStatus.permissionPermanentlyDenied:
        return AppCopy.permissionRequiredTitle;
      case ScanStatus.bluetoothOff:
        return 'Bluetooth is off';
      case ScanStatus.bluetoothUnsupported:
        return 'Bluetooth not supported';
    }
  }

  String? _subtitleForStatus(ScanState state) {
    if (state.status == ScanStatus.possibleRiskDetected) {
      return AppCopy.possibleRiskBody;
    }
    if (state.statusMessage != null) return state.statusMessage;
    if (state.status == ScanStatus.scanning && !state.hasElevatedRisk) {
      return AppCopy.noRiskWhileScanning;
    }
    return null;
  }

  String? _lastCheckedText(ScanState state) {
    if (state.status == ScanStatus.idle || state.status == ScanStatus.paused) {
      return null;
    }
    return relativeLastChecked(state.lastCheckedAt);
  }

  Widget _iconWidgetForStatus(ScanStatus status, RiskLevel riskLevel) {
    switch (status) {
      case ScanStatus.scanning:
      case ScanStatus.confirmingRisk:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningActive,
          size: 48,
        );
      case ScanStatus.resting:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningPaused,
          size: 48,
        );
      case ScanStatus.possibleRiskDetected:
        if (riskLevel == RiskLevel.medium) {
          return const UnrecordedIcon(
            asset: UnrecordedIconAsset.riskMedium,
            size: 48,
            color: UnrecordedColors.warning,
          );
        }
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.highRisk,
          size: 48,
        );
      case ScanStatus.permissionDenied:
      case ScanStatus.permissionPermanentlyDenied:
      case ScanStatus.bluetoothOff:
      case ScanStatus.bluetoothUnsupported:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.permissionsNeeded,
          size: 48,
        );
      case ScanStatus.error:
        return const UnrecordedIcon(
          asset: UnrecordedIconAsset.alert,
          size: 48,
          color: UnrecordedColors.danger,
        );
      case ScanStatus.paused:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningPaused,
          size: 48,
        );
      case ScanStatus.starting:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningActive,
          size: 48,
        );
      default:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.protectionOn,
          size: 48,
        );
    }
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

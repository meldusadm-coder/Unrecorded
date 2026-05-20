import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/scanner_provider.dart';
import '../../services/widget_sync_service.dart';
import 'scan_state.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSyncServiceProvider);

    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final showAlert = state.status == ScanStatus.possibleRiskDetected &&
        !state.alertDismissed;
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
            ScanStatusCard(
              icon: _iconWidgetForStatus(state.status),
              title: _titleForStatus(state),
              subtitle: _subtitleForStatus(state),
              lastCheckedText: _lastCheckedText(state),
            ),
            const SizedBox(height: 12),
            const HelperText(
              text: AppCopy.scanHelper,
              expandableDetail: PrivacyDisclaimer.detectionDisclaimer,
            ),
            const SizedBox(height: 12),
            _buildNextStep(context, state, controller),
            if (showAlert) ...[
              const SizedBox(height: 16),
              RiskAlertCard(
                title: AppCopy.alertCardTitle,
                body: AppCopy.alertCardBody,
                level: state.riskLevel,
                onViewDetails: () => context.push('/alert-info'),
                onDismiss: () => controller.dismissRiskAlert(),
              ),
              const SizedBox(height: 8),
              const HelperText(text: AppCopy.riskResultHelper),
            ],
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: state.isProtectionActive
                  ? AppCopy.pauseProtection
                  : AppCopy.turnOnProtection,
              icon: state.isProtectionActive
                  ? const UnrecordedStatusIcon(
                      asset: UnrecordedStatusAsset.scanningPaused,
                      size: 24,
                    )
                  : const AppLogo(size: 24),
              color: state.isProtectionActive ? UnrecordedColors.danger : null,
              onPressed: () async {
                if (state.isProtectionActive) {
                  await controller.pauseProtection();
                } else {
                  await controller.startProtection();
                }
              },
            ),
            if (state.signals.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Nearby signals (${state.signals.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...state.signals.map(_buildSignalCard),
            ],
            if (state.reasons.isNotEmpty && state.isProtectionActive) ...[
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
    switch (state.status) {
      case ScanStatus.permissionRequired:
        return const NextStepBanner(
          message:
              'Bluetooth or location permission is needed to scan nearby signals.',
          actionLabel: 'Open settings',
          onAction: openAppSettings,
        );
      case ScanStatus.possibleRiskDetected:
        return const NextStepBanner(
          message:
              'Stay aware of your surroundings. You can view details or dismiss the alert.',
        );
      case ScanStatus.scanning:
        if (!state.hasElevatedRisk) {
          return const NextStepBanner(
            message: AppCopy.noRiskWhileScanning,
          );
        }
        return const SizedBox.shrink();
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
      case ScanStatus.possibleRiskDetected:
        return AppCopy.possibleRiskTitle;
      case ScanStatus.paused:
        return 'Protection paused';
      case ScanStatus.error:
        return 'Scan issue';
      case ScanStatus.permissionRequired:
        return AppCopy.permissionRequiredTitle;
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
    final t = state.lastCheckedAt;
    if (t == null) return null;
    if (state.status == ScanStatus.idle || state.status == ScanStatus.paused) {
      return null;
    }
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Last checked: just now';
    if (diff.inMinutes < 60) {
      return 'Last checked: ${diff.inMinutes} min ago';
    }
    return 'Last checked: ${diff.inHours} h ago';
  }

  Widget _iconWidgetForStatus(ScanStatus status) {
    switch (status) {
      case ScanStatus.scanning:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningActive,
          size: 48,
        );
      case ScanStatus.possibleRiskDetected:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.highRisk,
          size: 48,
        );
      case ScanStatus.permissionRequired:
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

  Widget _buildSignalCard(DetectedSignal signal) {
    final name = signal.displayName ?? 'Unknown device';
    return SignalCard(
      name: name,
      subtitle: signal.id,
      rssi: signal.rssi,
      isSuspicious: _isSuspiciousName(signal.displayName),
    );
  }

  bool _isSuspiciousName(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    const keywords = [
      'ray-ban',
      'meta',
      'smart glasses',
      'spectacles',
      'camera',
      'glasses',
    ];
    return keywords.any(lower.contains);
  }
}

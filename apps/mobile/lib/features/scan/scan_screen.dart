import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/ads_service.dart';
import '../../services/scanner_provider.dart';
import '../../services/widget_sync_service.dart';
import 'scan_state.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _alertDismissed = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(widgetSyncServiceProvider);

    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final showAlert = state.status == ScanStatus.possibleRiskDetected &&
        !_alertDismissed;
    final hideAds = showAlert ||
        state.status == ScanStatus.permissionRequired ||
        state.status == ScanStatus.error;

    if (state.status != ScanStatus.possibleRiskDetected) {
      _alertDismissed = false;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(size: 26),
        ),
        title: const Text('Unrecorded'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => context.push('/help'),
          ),
          IconButton(
            key: const Key('settings_button'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  ScanStatusCard(
                    icon: _iconForStatus(state.status),
                    iconColor: _iconColorForStatus(context, state.status),
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
                  _buildNextStep(context, state),
                  if (showAlert) ...[
                    const SizedBox(height: 16),
                    RiskAlertCard(
                      title: AppCopy.alertCardTitle,
                      body: AppCopy.alertCardBody,
                      onViewDetails: () => context.push('/alert-info'),
                      onDismiss: () => setState(() => _alertDismissed = true),
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
                        ? Icons.pause_rounded
                        : Icons.shield_outlined,
                    color: state.isProtectionActive
                        ? Colors.red.shade400
                        : null,
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
            if (!hideAds)
              BottomAdSlot(
                onRemoveAdsTap: () => context.push('/remove-ads'),
                child: ref.watch(bannerAdWidgetProvider),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStep(BuildContext context, ScanState state) {
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
          onAction: () =>
              ref.read(scanControllerProvider.notifier).startProtection(),
        );
      case ScanStatus.idle:
      case ScanStatus.paused:
        return const NextStepBanner(
          message: 'Turn on protection to keep checking for possible recording risk.',
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

  IconData _iconForStatus(ScanStatus status) {
    switch (status) {
      case ScanStatus.scanning:
        return Icons.radar;
      case ScanStatus.possibleRiskDetected:
        return Icons.warning_amber_rounded;
      case ScanStatus.permissionRequired:
        return Icons.lock_outline;
      case ScanStatus.error:
        return Icons.error_outline;
      case ScanStatus.paused:
        return Icons.pause_circle_outline;
      default:
        return Icons.shield_outlined;
    }
  }

  Color? _iconColorForStatus(BuildContext context, ScanStatus status) {
    if (status == ScanStatus.possibleRiskDetected) {
      return Theme.of(context).colorScheme.error;
    }
    return null;
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

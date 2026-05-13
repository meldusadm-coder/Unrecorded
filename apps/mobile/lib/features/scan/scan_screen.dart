import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/scanner_provider.dart';
import 'scan_state.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unrecorded'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How detection works',
            onPressed: () => context.push('/alert-info'),
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const PrivacyNoticeCard(
              text: PrivacyDisclaimer.detectionDisclaimer,
            ),
            const SizedBox(height: 16),
            _StatusSection(state: state),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: state.status == ScanStatus.scanning
                  ? 'Stop scanning'
                  : 'Start scanning',
              icon: state.status == ScanStatus.scanning
                  ? Icons.stop_rounded
                  : Icons.radar_rounded,
              color: state.status == ScanStatus.scanning
                  ? Colors.red.shade400
                  : null,
              onPressed: () {
                if (state.status == ScanStatus.scanning) {
                  controller.stopScan();
                } else {
                  controller.startScan();
                }
              },
            ),
            const SizedBox(height: 20),
            if (state.signals.isNotEmpty) ...[
              Text(
                'Nearby signals (${state.signals.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...state.signals.map((s) => _buildSignalCard(s)),
            ],
            if (state.reasons.isNotEmpty &&
                state.status == ScanStatus.scanning) ...[
              const SizedBox(height: 16),
              Text(
                'Why this risk level?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...state.reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(DetectedSignal signal) {
    final name = signal.displayName ?? 'Unknown device';
    final isSuspicious = _isSuspiciousName(signal.displayName);
    return SignalCard(
      name: name,
      subtitle: signal.id,
      rssi: signal.rssi,
      isSuspicious: isSuspicious,
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

class _StatusSection extends StatelessWidget {
  final ScanState state;

  const _StatusSection({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RiskBadge(level: state.riskLevel),
        const SizedBox(height: 10),
        Text(
          _statusText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String get _statusText => switch (state.status) {
        ScanStatus.idle => 'Tap the button below to start scanning.',
        ScanStatus.scanning =>
          '${state.signals.length} signal${state.signals.length == 1 ? '' : 's'} detected nearby.',
        ScanStatus.paused => 'Scanning is paused.',
        ScanStatus.error => 'An error occurred. Try scanning again.',
      };
}

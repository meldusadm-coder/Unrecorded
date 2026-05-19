import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

class AlertExplanationScreen extends StatelessWidget {
  const AlertExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('How detection works')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _section(
              theme,
              'Why you may see a warning',
              'Unrecorded scans for nearby Bluetooth signals and compares '
                  'them against patterns associated with smart glasses and '
                  'wearable recording devices. If a match is found, the app '
                  'shows a privacy-risk warning.',
            ),
            const Divider(height: 32),
            Text(
              'What the risk levels mean',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _riskRow(
              theme,
              RiskLevel.low,
              'No suspicious signals detected. This does not guarantee '
              'there are no recording devices nearby — it only means '
              'none were found by the current scan.',
            ),
            const SizedBox(height: 8),
            _riskRow(
              theme,
              RiskLevel.medium,
              'One or more signals match patterns that may be associated '
              'with smart glasses or recording devices. This is a '
              'possible risk, not a confirmed threat.',
            ),
            const SizedBox(height: 8),
            _riskRow(
              theme,
              RiskLevel.high,
              'Strong or repeated signals closely match known recording-'
              'device patterns. There is a higher chance that such a '
              'device is nearby, but this still cannot be proven.',
            ),
            const Divider(height: 32),
            _section(
              theme,
              'What the app can detect',
              '• Bluetooth Low Energy (BLE) advertisements from nearby '
                  'devices.\n'
                  '• Device names and signal strength that may match known '
                  'smart-glasses patterns.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'What the app cannot detect',
              '• Devices that do not use Bluetooth or hide their identity.\n'
                  '• Whether a device is actually recording.\n'
                  '• Cameras that are not part of a BLE-enabled wearable.',
            ),
            const Divider(height: 32),
            _section(
              theme,
              'Why detection is probabilistic',
              'Bluetooth signals can be hidden, randomised, or spoofed. '
                  'Smart glasses may not advertise recognisable names. Signal '
                  'strength varies with distance and environment. For these '
                  'reasons, Unrecorded can only provide risk indicators — '
                  'never certainty.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
      ],
    );
  }

  Widget _riskRow(ThemeData theme, RiskLevel level, String explanation) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RiskBadge(level: level),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            explanation,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

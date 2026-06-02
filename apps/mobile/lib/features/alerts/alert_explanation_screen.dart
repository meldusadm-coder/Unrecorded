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
            const HelperText(
              text: AppCopy.riskResultHelper,
              expandableDetail: PrivacyDisclaimer.detectionDisclaimer,
            ),
            const SizedBox(height: 20),
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
              'possible risk, not a proven threat.',
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
                  'Address prefix hints are weak and are not proof of a '
                  'specific device. Signal strength (RSSI) is noisy. Smart '
                  'glasses may not advertise recognisable names. Unrecorded '
                  'can only provide risk indicators — never certainty.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Scanning on Android',
              'On Android 12 and later, Unrecorded requests Bluetooth scan '
                  'permission without using your location for scanning '
                  '(neverForLocation). Some BLE advertisements may still be '
                  'filtered by the system for privacy.\n\n'
                  'Scanning runs in short foreground windows with rest '
                  'periods. Keep the app open for the most reliable results. '
                  'Background scanning is limited and there is no always-on '
                  'protection service in this version.',
            ),
            const SizedBox(height: 12),
            _section(
              theme,
              'Repeated sightings',
              'If the same possible-risk signal is seen more than once in a '
                  'session, confidence may increase modestly. Stale signals '
                  'expire after about a minute without a new observation.',
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

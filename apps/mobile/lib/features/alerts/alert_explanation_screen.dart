import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../scan/unrecorded_disclosure_sheet.dart';

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
            Text(
              'Unrecorded compares nearby Bluetooth signals with patterns '
              'associated with smart glasses and wearable recording devices. '
              'A match is a possible risk, not proof.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
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
            const UnrecordedDisclosureAccordion(
              title: 'What the app can detect',
              body: '• Bluetooth Low Energy (BLE) advertisements from nearby '
                  'devices.\n'
                  '• Device names and signal strength that may match known '
                  'smart-glasses patterns.',
            ),
            const UnrecordedDisclosureAccordion(
              title: 'What the app cannot detect',
              body:
                  '• Devices that do not use Bluetooth or hide their identity.\n'
                  '• Whether a device is actually recording.\n'
                  '• Cameras that are not part of a BLE-enabled wearable.',
            ),
            const UnrecordedDisclosureAccordion(
              title: 'Why detection is probabilistic',
              body: 'Bluetooth signals can be hidden, randomised, or spoofed. '
                  'Address prefix hints are weak and are not proof of a '
                  'specific device. Signal strength (RSSI) is noisy. Smart '
                  'glasses may not advertise recognisable names. Unrecorded '
                  'can only provide risk indicators — never certainty.',
            ),
            const UnrecordedDisclosureAccordion(
              title: 'Scanning on Android',
              body:
                  'On Android 12 and later, Unrecorded requests Bluetooth scan '
                  'permission without using your location for scanning '
                  '(neverForLocation). Some BLE advertisements may still be '
                  'filtered by the system for privacy.\n\n'
                  'Scanning runs in short scan and rest windows. You can also '
                  'turn on optional background protection, which uses a '
                  'persistent foreground service while Android allows it. '
                  'Keep the app open for the most reliable results when '
                  'background protection is off.',
            ),
            const UnrecordedDisclosureAccordion(
              title: 'Repeated sightings',
              body:
                  'If the same possible-risk signal is seen more than once in a '
                  'session, confidence may increase modestly. Stale signals '
                  'expire after about a minute without a new observation.',
            ),
            const UnrecordedDisclosureAccordion(
              title: AppCopy.recentRiskExplanationSectionTitle,
              body: AppCopy.recentRiskExplanationSectionBody,
            ),
            const SizedBox(height: 16),
            Text(
              PrivacyDisclaimer.detectionDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const PrivacyNoticeCard(
              text: PrivacyDisclaimer.privacyModel,
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 20),
            _tile(
              theme,
              icon: Icons.smartphone_outlined,
              title: 'Local-first',
              subtitle:
                  'All scanning happens on your device. Nothing is uploaded.',
            ),
            _tile(
              theme,
              icon: Icons.person_off_outlined,
              title: 'No account required',
              subtitle:
                  'Unrecorded works without sign-up, login, or any account.',
            ),
            _tile(
              theme,
              icon: Icons.cloud_off_outlined,
              title: 'No cloud upload',
              subtitle:
                  'Scan data stays on your device unless you choose otherwise.',
            ),
            _tile(
              theme,
              icon: Icons.analytics_outlined,
              title: 'No analytics or tracking',
              subtitle:
                  'The app does not include analytics, telemetry, or ad SDKs.',
            ),
            const Divider(height: 32),
            Text('Funding', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              PrivacyDisclaimer.fundingNote,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            Text(
              'Unrecorded v0.1.0',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}

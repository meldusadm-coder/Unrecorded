import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'services/notification_payloads.dart';

import 'features/alerts/alert_details_screen.dart';
import 'features/alerts/alert_explanation_screen.dart';
import 'features/alerts/recent_risk_screen.dart';
import 'features/feedback/feedback_screen.dart';
import 'features/help/help_screen.dart';
import 'features/monetisation/remove_ads_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'main_shell.dart';

/// Shared navigator key for notification deep links and in-app routing.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Educational FAQ about detection limits and risk levels.
const alertInfoRoute = '/alert-info';

/// Live alert context (devices, level, reasons) from the current scan.
const alertDetailsRoute = '/alert-details';

/// Short-lived recent possible-risk reminder details.
const recentRiskRoute = '/recent-risk';

/// Custom scheme host for Android VIEW intents (`unrecorded://open/...`).
const deepLinkScheme = 'unrecorded';
const deepLinkHost = 'open';

/// Play Console pre-launch report deep links (strategy A: secondary screens).
///
/// Home (`/`) is already crawled via the launcher. Paste these URIs in
/// **Test and release → Testing → Pre-launch report → Settings** after upload.
const playPreLaunchDeepLinks = <String>[
  '$deepLinkScheme://$deepLinkHost/help',
  '$deepLinkScheme://$deepLinkHost/alert-info',
  '$deepLinkScheme://$deepLinkHost/settings',
];

GoRouter buildAppRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ScanScreen(),
            ),
            GoRoute(
              path: '/help',
              builder: (context, state) => const HelpScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/feedback',
              builder: (context, state) => const FeedbackScreen(),
            ),
          ],
        ),
        GoRoute(
          path: alertDetailsRoute,
          builder: (context, state) => const AlertDetailsScreen(),
        ),
        GoRoute(
          path: alertInfoRoute,
          builder: (context, state) => const AlertExplanationScreen(),
        ),
        GoRoute(
          path: recentRiskRoute,
          builder: (context, state) => const RecentRiskScreen(),
        ),
        GoRoute(
          path: '/remove-ads',
          builder: (context, state) => const RemoveAdsScreen(),
        ),
      ],
    );

/// Navigate to live alert details (notification tap / cold start).
void navigateToAlertDetails() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  GoRouter.of(context).push(alertDetailsRoute);
}

/// Navigate to the main protection / scan screen (status notification tap).
void navigateToProtectionScreen() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  GoRouter.of(context).go('/');
}

/// @deprecated Use [navigateToAlertDetails]. Kept for tests migrating off old name.
void navigateToAlertInfo() => navigateToAlertDetails();

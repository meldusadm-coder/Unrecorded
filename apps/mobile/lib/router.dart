import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/alerts/alert_details_screen.dart';
import 'features/alerts/alert_explanation_screen.dart';
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

const notificationAlertPayload = 'alert-details';

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

/// @deprecated Use [navigateToAlertDetails]. Kept for tests migrating off old name.
void navigateToAlertInfo() => navigateToAlertDetails();

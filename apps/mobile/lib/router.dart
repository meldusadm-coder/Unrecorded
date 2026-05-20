import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/alerts/alert_explanation_screen.dart';
import 'features/help/help_screen.dart';
import 'features/monetisation/remove_ads_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';

/// Shared navigator key for notification deep links and in-app routing.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Route opened when the user taps a risk notification.
const alertInfoRoute = '/alert-info';

const notificationAlertPayload = 'alert-info';

GoRouter buildAppRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ScanScreen()),
        GoRoute(
          path: '/help',
          builder: (context, state) => const HelpScreen(),
        ),
        GoRoute(
          path: alertInfoRoute,
          builder: (context, state) => const AlertExplanationScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/remove-ads',
          builder: (context, state) => const RemoveAdsScreen(),
        ),
      ],
    );

/// Navigate to alert details (notification tap / cold start).
void navigateToAlertInfo() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  GoRouter.of(context).push(alertInfoRoute);
}

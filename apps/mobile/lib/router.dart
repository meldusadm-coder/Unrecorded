import 'package:go_router/go_router.dart';

import 'features/alerts/alert_explanation_screen.dart';
import 'features/help/help_screen.dart';
import 'features/monetisation/remove_ads_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';

GoRouter buildAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ScanScreen()),
        GoRoute(
          path: '/help',
          builder: (context, state) => const HelpScreen(),
        ),
        GoRoute(
          path: '/alert-info',
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

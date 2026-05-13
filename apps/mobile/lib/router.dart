import 'package:go_router/go_router.dart';

import 'features/alerts/alert_explanation_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';

GoRouter buildAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ScanScreen(),
        ),
        GoRoute(
          path: '/alert-info',
          builder: (context, state) => const AlertExplanationScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'router.dart';

class UnrecordedApp extends StatefulWidget {
  const UnrecordedApp({super.key});

  @override
  State<UnrecordedApp> createState() => _UnrecordedAppState();
}

class _UnrecordedAppState extends State<UnrecordedApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Unrecorded',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: UnrecordedColorScheme.light(),
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: UnrecordedColors.surface,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: UnrecordedColorScheme.dark(),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: UnrecordedColors.background,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

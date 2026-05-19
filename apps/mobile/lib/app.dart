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
        colorSchemeSeed: const Color(0xFF5C6BC0),
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF5C6BC0),
        useMaterial3: true,
        brightness: Brightness.dark,
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

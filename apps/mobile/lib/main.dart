import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'services/protection_orchestrator_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await HomeWidget.setAppGroupId('group.com.unrecorded.app');
  } catch (_) {
    // App group is iOS-only; Android uses HomeWidget default storage.
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AppBootstrap(
        child: UnrecordedApp(),
      ),
    ),
  );
}

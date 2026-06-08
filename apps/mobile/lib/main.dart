import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register the IPC port so the task isolate can send data to the main isolate.
  FlutterForegroundTask.initCommunicationPort();

  try {
    await HomeWidget.setAppGroupId('group.com.unrecorded.app');
  } catch (_) {
    // App group is iOS-only; Android uses HomeWidget default storage.
  }

  runApp(
    const ProviderScope(
      child: AppBootstrap(
        child: UnrecordedApp(),
      ),
    ),
  );
}

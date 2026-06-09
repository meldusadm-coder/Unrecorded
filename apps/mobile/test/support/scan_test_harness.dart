import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_screen.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/scan_lifecycle_coordinator.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_mobile/services/signal_ui_mapper.dart';
import 'package:unrecorded_mobile/services/widget_sync_service.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

/// A [ScanRuntime] that reports non-Android and never calls any platform APIs.
class NoopScanRuntime extends ScanRuntime {
  const NoopScanRuntime();

  @override
  bool get isAndroid => false;
}

/// A [ScanController] that starts with a pre-built [ScanState], useful for
/// widget tests that need to verify rendering for specific states without
/// driving the full scan lifecycle.
class StateHarnessController extends ScanController {
  StateHarnessController(ScanState value)
      : super(
          coordinator: ScanLifecycleCoordinator(
            scannerFactory: () => FakeRadioScanner(),
            runtime: const NoopScanRuntime(),
            scannerModeFactory: () => ScannerMode.demo,
            pipeline: DetectionPipeline(),
          ),
          pipeline: DetectionPipeline(),
          mapper: const SignalUiMapper(),
          isBackgroundOwnsScanning: () => false,
        ) {
    state = value;
  }
}

/// Pumps [ScanScreen] with the given [state] pre-loaded via [StateHarnessController].
Future<void> pumpScanScreen(WidgetTester tester, ScanState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanControllerProvider
            .overrideWith((ref) => StateHarnessController(state)),
        widgetSyncServiceProvider
            .overrideWith((ref) => const WidgetSyncService()),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ),
  );
  await tester.pump();
}

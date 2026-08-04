import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_protection_state.dart';
import 'protection_orchestrator.dart';
import 'protection_orchestrator_providers.dart';
import 'protection_state.dart';

export 'background_protection_state.dart';

/// Compatibility facade: routes Settings / scan toggles through the orchestrator.
class BackgroundProtectionController
    extends StateNotifier<BackgroundProtectionState> {
  BackgroundProtectionController(this._ref)
      : super(const BackgroundProtectionState()) {
    _sub = _ref.listen<ProtectionOrchestratorState>(
      protectionOrchestratorProvider,
      (_, next) {
        state = backgroundProtectionStateFromOrchestrator(next);
      },
      fireImmediately: true,
    );
  }

  final Ref _ref;
  ProviderSubscription<ProtectionOrchestratorState>? _sub;

  ProtectionOrchestrator get _orch =>
      _ref.read(protectionOrchestratorProvider.notifier);

  void disposeController() {
    _sub?.close();
  }

  Future<void> reconcileBackgroundProtection() async {
    if (!Platform.isAndroid) return;
    await _orch.reconcileOnLaunchOrResume();
  }

  Future<bool> enable() async {
    if (!Platform.isAndroid) return false;
    final mode = await _orch.setBackgroundModePreferred(true);
    if (mode is ProtectionBusy || mode is ProtectionDisposed) return false;
    final outcome = await _orch.turnProtectionOn();
    return outcome is ProtectionCompleted;
  }

  Future<void> disable({bool recordExplicitStop = true}) async {
    if (recordExplicitStop) {
      await _orch.stopAllProtection();
    } else {
      await _orch.setBackgroundModePreferred(false);
      final orchState = _ref.read(protectionOrchestratorProvider);
      if (orchState.confirmedOwner != ScannerOwner.none ||
          orchState.foregroundMayBeActive ||
          orchState.backgroundMayBeActive) {
        await _orch.stopAllProtection();
      }
    }
  }

  /// Debug UAT: ask the task isolate to post a test risk notification.
  Future<void> requestTestRiskNotification() async {
    if (!state.serviceRunning) return;
    FlutterForegroundTask.sendDataToTask(const {'type': 'test_risk_alert'});
  }
}

final backgroundProtectionControllerProvider = StateNotifierProvider<
    BackgroundProtectionController, BackgroundProtectionState>((ref) {
  final controller = BackgroundProtectionController(ref);
  ref.onDispose(controller.disposeController);
  return controller;
});

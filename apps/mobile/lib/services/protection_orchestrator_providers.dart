import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:shared_preferences/shared_preferences.dart';

import 'android_protection_protocol_store.dart';
import 'background_protection_state.dart';
import 'background_protection_preflight.dart';
import 'background_protection_snapshot.dart';
import 'fake_protection_protocol_store.dart';
import 'foreground_service_controller.dart';
import 'protection_orchestrator.dart';
import 'protection_protocol_store.dart';
import 'protection_state.dart';
import 'risk_notification_service.dart';
import 'scanner_provider.dart';
import 'single_engine_protection_protocol_store.dart';

/// Override in [ProviderScope] after [SharedPreferences.getInstance].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) {
    throw StateError('Override sharedPreferencesProvider in ProviderScope');
  },
  // Always fails unless overridden — do not auto-retry (Riverpod 3 default).
  retry: (retryCount, error) => null,
);

final backgroundProtectionPreflightProvider =
    Provider<BackgroundProtectionPreflight>((ref) {
  return BackgroundProtectionPreflight(
    runtime: ref.watch(scanRuntimeProvider),
    notifications: ref.watch(riskNotificationServiceProvider),
  );
});

final protectionProtocolStoreProvider =
    Provider<ProtectionProtocolStore>((ref) {
  if (Platform.isAndroid) {
    final store = AndroidProtectionProtocolStore();
    ref.onDispose(() => unawaited(store.dispose()));
    return store;
  }
  // Prefer SharedPreferences when overridden (iOS / desktop). Fall back to an
  // in-memory fake when tests have not overridden the prefs provider.
  try {
    final prefs = ref.read(sharedPreferencesProvider);
    final store = SingleEngineProtectionProtocolStore(prefs: prefs);
    ref.onDispose(() => unawaited(store.dispose()));
    return store;
  } on ProviderException catch (e) {
    if (e.exception is! StateError) rethrow;
    final store = FakeProtectionProtocolStore();
    ref.onDispose(() => unawaited(store.dispose()));
    return store;
  } on StateError {
    final store = FakeProtectionProtocolStore();
    ref.onDispose(() => unawaited(store.dispose()));
    return store;
  }
});

final protectionOrchestratorProvider =
    StateNotifierProvider<ProtectionOrchestrator, ProtectionOrchestratorState>(
        (ref) {
  final store = ref.watch(protectionProtocolStoreProvider);
  final claim = ref.watch(backgroundOwnershipClaimProvider);
  final orchestrator = ProtectionOrchestrator(
    protocolStore: store,
    backgroundClaim: claim,
    startForeground: ({required lease}) {
      return ref.read(scanControllerProvider.notifier).startProtection(
            lease: lease,
          );
    },
    pauseForeground: () {
      return ref.read(scanControllerProvider.notifier).pauseProtection();
    },
    foregroundService: ref.watch(foregroundServiceControllerProvider),
    backgroundPreflight: ref.watch(backgroundProtectionPreflightProvider),
    applyMirroredScanState: (scanState) {
      ref.read(scanControllerProvider.notifier).applyMirroredState(scanState);
    },
    onOwnerChanged: (owner) {
      ref.read(scannerOwnerProvider.notifier).state = owner;
    },
    supportBackground: Platform.isAndroid,
  );
  return orchestrator;
});

BackgroundProtectionState backgroundProtectionStateFromOrchestrator(
  ProtectionOrchestratorState state,
) {
  final tuple = state.lastConfirmedTuple;
  final preferredBackground = tuple?.backgroundModePreferred == true;
  final intentOn = tuple?.protectionEnabled == true;
  final serviceRunning = state.confirmedOwner == ScannerOwner.background ||
      state.backgroundMechanics == BackgroundServiceMechanics.ready ||
      state.backgroundMechanics == BackgroundServiceMechanics.runningUnready;

  final enabled = (intentOn && preferredBackground) ||
      serviceRunning ||
      (preferredBackground &&
          state.issue ==
              BackgroundProtectionIssue.androidStoppedBackgroundProtection);

  var stoppedReason = BackgroundProtectionStoppedReason.none;
  if (state.issue ==
      BackgroundProtectionIssue.androidStoppedBackgroundProtection) {
    stoppedReason = BackgroundProtectionStoppedReason.stoppedByAndroid;
  } else if (state.issue == BackgroundProtectionIssue.taskBlocked ||
      state.issue == BackgroundProtectionIssue.mainPreflightFailed) {
    stoppedReason = BackgroundProtectionStoppedReason.blocked;
  }

  return BackgroundProtectionState(
    enabled: enabled,
    serviceRunning: serviceRunning,
    stoppedReason: stoppedReason,
    lastFailureMessage: state.issue?.name,
  );
}

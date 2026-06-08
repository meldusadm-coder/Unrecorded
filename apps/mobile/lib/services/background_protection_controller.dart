import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/scan_state.dart';
import 'background_protection_preflight.dart';
import 'background_protection_prefs.dart';
import 'background_protection_snapshot.dart';
import 'background_scan_task_handler.dart';
import 'foreground_service_controller.dart';
import 'risk_notification_service.dart';
import 'scanner_provider.dart';

/// UI-facing state for background protection.
class BackgroundProtectionState {
  const BackgroundProtectionState({
    this.enabled = false,
    this.serviceRunning = false,
    this.stoppedReason = BackgroundProtectionStoppedReason.none,
    this.lastFailureMessage,
  });

  final bool enabled;
  final bool serviceRunning;
  final BackgroundProtectionStoppedReason stoppedReason;
  final String? lastFailureMessage;

  bool get ownsScanning => serviceRunning;

  bool get showsStoppedByAndroidBanner =>
      enabled &&
      !serviceRunning &&
      stoppedReason == BackgroundProtectionStoppedReason.stoppedByAndroid;

  BackgroundProtectionState copyWith({
    bool? enabled,
    bool? serviceRunning,
    BackgroundProtectionStoppedReason? stoppedReason,
    String? lastFailureMessage,
    bool clearLastFailureMessage = false,
  }) {
    return BackgroundProtectionState(
      enabled: enabled ?? this.enabled,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      stoppedReason: stoppedReason ?? this.stoppedReason,
      lastFailureMessage: clearLastFailureMessage
          ? null
          : (lastFailureMessage ?? this.lastFailureMessage),
    );
  }
}

/// Coordinates opt-in Android background protection.
///
/// Risk alerts and recent-risk recording while the foreground service runs are
/// owned by the task isolate; this controller only mirrors safe scan state.
class BackgroundProtectionController
    extends StateNotifier<BackgroundProtectionState> {
  BackgroundProtectionController({
    required ForegroundServiceController foregroundService,
    required BackgroundProtectionPreflight preflight,
    required void Function(ScanState state) applyMirroredScanState,
    required Future<void> Function() pauseMainProtection,
    required void Function(bool running) onServiceRunningChanged,
    bool? isAndroidPlatform,
  })  : _isAndroid = isAndroidPlatform ?? Platform.isAndroid,
        _foregroundService = foregroundService,
        _preflight = preflight,
        _applyMirroredScanState = applyMirroredScanState,
        _pauseMainProtection = pauseMainProtection,
        _onServiceRunningChanged = onServiceRunningChanged,
        super(const BackgroundProtectionState()) {
    _foregroundService.addDataCallback(_onTaskData);
  }

  final bool _isAndroid;
  final ForegroundServiceController _foregroundService;
  final BackgroundProtectionPreflight _preflight;
  final void Function(ScanState state) _applyMirroredScanState;
  final Future<void> Function() _pauseMainProtection;
  final void Function(bool running) _onServiceRunningChanged;

  void disposeController() {
    _foregroundService.removeDataCallback(_onTaskData);
  }

  void _onTaskData(Object data) {
    final snapshot = BackgroundProtectionSnapshot.fromJson(data);
    if (snapshot == null) return;

    var next = state.copyWith(
      serviceRunning: snapshot.serviceRunning,
      stoppedReason: snapshot.stoppedReason,
      clearLastFailureMessage: true,
    );

    if (!snapshot.serviceRunning &&
        snapshot.stoppedReason ==
            BackgroundProtectionStoppedReason.stoppedByAndroid) {
      next = next.copyWith(enabled: true);
    }

    state = next;
    _onServiceRunningChanged(snapshot.serviceRunning);

    _applyMirroredScanState(
      snapshot.toScanState(protectionRequested: snapshot.serviceRunning),
    );
  }

  /// Reconciles persisted user intent with the foreground-service process.
  Future<void> reconcileBackgroundProtection() async {
    if (!_isAndroid) return;

    final prefs = await BackgroundProtectionPrefs.load();
    final running = await _foregroundService.isRunning;

    if (prefs.explicitlyStopped) {
      await prefs.clearExplicitlyStopped();
      state = const BackgroundProtectionState();
      _onServiceRunningChanged(false);
      return;
    }

    if (!prefs.backgroundProtectionEnabled) {
      state = state.copyWith(
        enabled: false,
        serviceRunning: running,
        stoppedReason: BackgroundProtectionStoppedReason.none,
      );
      _onServiceRunningChanged(running);
      return;
    }

    if (running) {
      await _pauseMainProtection();
      _onServiceRunningChanged(true);
      state = state.copyWith(
        enabled: true,
        serviceRunning: true,
        stoppedReason: BackgroundProtectionStoppedReason.none,
      );
      return;
    }

    _onServiceRunningChanged(false);
    state = state.copyWith(
      enabled: true,
      serviceRunning: false,
      stoppedReason: BackgroundProtectionStoppedReason.stoppedByAndroid,
    );
  }

  Future<bool> enable() async {
    if (!_isAndroid) return false;

    final preflight = await _preflight.check();
    if (!preflight.isOk) {
      state = state.copyWith(
        lastFailureMessage: _preflight.messageFor(preflight.failure!),
      );
      return false;
    }

    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.setBackgroundProtectionEnabled(true);
    await prefs.clearExplicitlyStopped();

    await _pauseMainProtection();

    final result = await _foregroundService.start(
      notificationTitle: AppCopy.backgroundProtectionNotificationTitle,
      notificationText: AppCopy.backgroundProtectionNotificationDefaultBody,
      notificationButtons: [
        const NotificationButton(
          id: kFgsStopButtonId,
          text: AppCopy.backgroundProtectionStopAction,
        ),
      ],
      callback: backgroundScanTaskCallback,
    );

    if (result is ServiceRequestFailure) {
      await prefs.setBackgroundProtectionEnabled(false);
      state = state.copyWith(
        enabled: false,
        serviceRunning: false,
        lastFailureMessage: AppCopy.backgroundProtectionServiceStartFailed,
      );
      if (kDebugMode || kProfileMode) {
        debugPrint(
          '[BackgroundProtectionController] start failed: ${result.error}',
        );
      }
      return false;
    }

    _onServiceRunningChanged(true);
    state = state.copyWith(
      enabled: true,
      serviceRunning: true,
      stoppedReason: BackgroundProtectionStoppedReason.none,
      clearLastFailureMessage: true,
    );
    return true;
  }

  Future<void> disable({bool recordExplicitStop = true}) async {
    final prefs = await BackgroundProtectionPrefs.load();
    if (recordExplicitStop) {
      await prefs.recordExplicitStop();
    } else {
      await prefs.setBackgroundProtectionEnabled(false);
    }

    await _foregroundService.stop();

    _onServiceRunningChanged(false);
    state = const BackgroundProtectionState();
  }

  /// Debug UAT: ask the task isolate to post a test risk notification.
  Future<void> requestTestRiskNotification() async {
    if (!state.serviceRunning) return;
    FlutterForegroundTask.sendDataToTask(const {'type': 'test_risk_alert'});
  }
}

final backgroundProtectionPreflightProvider =
    Provider<BackgroundProtectionPreflight>((ref) {
  return BackgroundProtectionPreflight(
    runtime: ref.watch(scanRuntimeProvider),
    notifications: ref.watch(riskNotificationServiceProvider),
  );
});

final backgroundProtectionControllerProvider = StateNotifierProvider<
    BackgroundProtectionController, BackgroundProtectionState>((ref) {
  final controller = BackgroundProtectionController(
    foregroundService: ref.watch(foregroundServiceControllerProvider),
    preflight: ref.watch(backgroundProtectionPreflightProvider),
    applyMirroredScanState: (scanState) {
      ref.read(scanControllerProvider.notifier).applyMirroredState(scanState);
    },
    pauseMainProtection: () {
      return ref.read(scanControllerProvider.notifier).pauseProtection(
            persist: false,
          );
    },
    onServiceRunningChanged: (running) {
      ref.read(backgroundOwnsScanningProvider.notifier).state = running;
    },
  );

  ref.onDispose(controller.disposeController);
  return controller;
});

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'background_protection_prefs.dart';
import 'background_protection_snapshot.dart';
import 'background_risk_alert_notifier.dart';
import 'background_scan_runtime.dart';
import 'protection_status_notification.dart';
import 'recent_risk_recording.dart';
import 'scan_lifecycle_coordinator.dart';
import 'scan_runtime.dart';
import 'signal_ui_mapper.dart';

// Top-level entry point required by flutter_foreground_task.
@pragma('vm:entry-point')
void backgroundScanTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundScanTaskHandler());
}

// ---------------------------------------------------------------------------

class _BackgroundScanTaskHandler extends TaskHandler {
  ScanLifecycleCoordinator? _coordinator;
  final BackgroundRiskAlertNotifier _riskNotifier =
      BackgroundRiskAlertNotifier();
  final SignalUiMapper _mapper = const SignalUiMapper();
  ScanStatus? _previousStatus;
  bool _serviceRunning = true;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _log('task started (starter=${starter.name})');
    _serviceRunning = true;

    final runtime = const BackgroundScanRuntime();
    final preflight = await runtime.ensureAndroidReady();
    if (!preflight.isOk) {
      _sendSnapshot(_blockedSnapshot(preflight.failure!));
      return;
    }

    final coordinator = ScanLifecycleCoordinator(
      scannerFactory: BleRadioScanner.new,
      runtime: runtime,
      scannerModeFactory: () => ScannerMode.auto,
    );
    coordinator.onStateChanged = _onCoordinatorState;
    _coordinator = coordinator;

    final startFailure = await _coordinator!.startProtection();
    if (startFailure != null) {
      _sendSnapshot(_blockedSnapshot(startFailure));
      return;
    }

    _log('protection started');
    _sendSnapshot(
      const BackgroundProtectionSnapshot(
        status: ScanStatus.scanning,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: true,
      ),
    );
  }

  void _onCoordinatorState(ScanState state, PipelineResult pipelineResult) {
    final (risk, other) =
        _mapper.partition(pipelineResult.snapshot.assessments);

    final snapshot = BackgroundProtectionSnapshot(
      status: state.status,
      riskLevel: pipelineResult.scoring.level,
      score: pipelineResult.scoring.totalScore,
      reasonLabels: pipelineResult.scoring.reasons,
      possibleRiskCount: risk.length,
      otherNearbyCount: other.length,
      lastCheckedAt: pipelineResult.snapshot.capturedAt,
      isDemoMode: _coordinator?.isDemoMode ?? false,
      serviceRunning: _serviceRunning,
    );

    _sendSnapshot(snapshot);
    unawaited(_updateForegroundNotification(state.status));

    if (_previousStatus != ScanStatus.possibleRiskDetected &&
        state.status == ScanStatus.possibleRiskDetected) {
      unawaited(
        recordRecentRiskFromBackground(
          riskLevel: pipelineResult.scoring.level,
          assessments: pipelineResult.snapshot.assessments,
        ),
      );
      unawaited(
        _riskNotifier.showRiskAlertIfEnabled(
          riskLevel: pipelineResult.scoring.level,
        ),
      );
    }
    _previousStatus = state.status;
  }

  BackgroundProtectionSnapshot _blockedSnapshot(Object failure) {
    final status = switch (failure) {
      ScanPreflightFailure.permissionDenied => ScanStatus.permissionDenied,
      ScanPreflightFailure.permissionPermanentlyDenied =>
        ScanStatus.permissionPermanentlyDenied,
      ScanPreflightFailure.bluetoothOff => ScanStatus.bluetoothOff,
      ScanPreflightFailure.bluetoothUnsupported =>
        ScanStatus.bluetoothUnsupported,
      _ => ScanStatus.error,
    };

    return BackgroundProtectionSnapshot(
      status: status,
      riskLevel: RiskLevel.low,
      score: 0,
      reasonLabels: const [],
      possibleRiskCount: 0,
      otherNearbyCount: 0,
      isDemoMode: false,
      serviceRunning: false,
      stoppedReason: BackgroundProtectionStoppedReason.blocked,
    );
  }

  Future<void> _updateForegroundNotification(ScanStatus status) async {
    if (!_serviceRunning) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: AppCopy.backgroundProtectionNotificationTitle,
        notificationText: protectionStatusBodyFor(status),
        notificationButtons: [
          const NotificationButton(
            id: kFgsStopButtonId,
            text: AppCopy.backgroundProtectionStopAction,
          ),
        ],
      );
    } catch (e) {
      _log('notification update failed: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _log('task destroyed (isTimeout=$isTimeout)');
    _serviceRunning = false;
    await _coordinator?.pauseProtection();
    _coordinator = null;
    _sendSnapshot(
      const BackgroundProtectionSnapshot(
        status: ScanStatus.paused,
        riskLevel: RiskLevel.low,
        score: 0,
        reasonLabels: [],
        possibleRiskCount: 0,
        otherNearbyCount: 0,
        isDemoMode: false,
        serviceRunning: false,
      ),
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == kFgsStopButtonId) {
      _log('Stop button pressed from notification');
      unawaited(_handleExplicitStop());
    }
  }

  Future<void> _handleExplicitStop() async {
    final prefs = await BackgroundProtectionPrefs.load();
    await prefs.recordExplicitStop();
    await FlutterForegroundTask.stopService();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['type'] == 'test_risk_alert') {
      _log('test risk alert requested');
      unawaited(_riskNotifier.showTestAlert());
    }
  }

  void _sendSnapshot(BackgroundProtectionSnapshot snapshot) {
    FlutterForegroundTask.sendDataToMain(snapshot.toJson());
  }

  void _log(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint('[BackgroundScanTask] $message');
    }
  }
}

/// Notification button id for the Stop action.
const kFgsStopButtonId = 'bg_stop';

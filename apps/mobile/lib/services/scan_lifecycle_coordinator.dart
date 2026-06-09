import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_radio/unrecorded_radio.dart';

import '../features/scan/scan_state.dart';
import 'scan_runtime.dart';
import 'scanner_cadence_config.dart';
import 'scanner_manager.dart';

/// Coordinates protection lifecycle, cadence, and detection pipeline.
class ScanLifecycleCoordinator {
  ScanLifecycleCoordinator({
    required RadioScanner Function() scannerFactory,
    required ScanRuntime runtime,
    required ScannerMode Function() scannerModeFactory,
    DetectionPipeline? pipeline,
    ScannerCadenceConfig? cadence,
    Duration startupGraceDuration = const Duration(seconds: 5),
    int requiredElevatedScans = 2,
  })  : _runtime = runtime,
        _scannerModeFactory = scannerModeFactory,
        pipeline = pipeline ?? DetectionPipeline(),
        _manager = ScannerManager(
          scannerFactory: scannerFactory,
          cadence: cadence ?? defaultScannerCadence,
        ),
        _startupGraceDuration = startupGraceDuration,
        _requiredElevatedScans = requiredElevatedScans {
    _wireManager();
  }

  final ScanRuntime _runtime;
  final ScannerMode Function() _scannerModeFactory;
  final DetectionPipeline pipeline;
  final ScannerManager _manager;
  final Duration _startupGraceDuration;
  final int _requiredElevatedScans;

  DateTime? _protectionStartedAt;
  int _consecutiveElevatedScans = 0;
  bool _protectionRequested = false;

  void Function(ScanState state, PipelineResult pipelineResult)? onStateChanged;

  ScannerMode get scannerMode => _scannerModeFactory();
  bool get protectionRequested => _protectionRequested;

  /// Whether scanning is effectively fake/demo data rather than real BLE.
  ///
  /// True for explicit demo mode and for the non-Android auto-mode fallback,
  /// which uses [FakeRadioScanner] because real BLE scanning is Android-only.
  /// UI must disclose this so fake scans are never presented as live data.
  bool get isDemoMode => scannerMode == ScannerMode.demo || !_runtime.isAndroid;

  void _wireManager() {
    _manager.onBatch = _onBatch;
    _manager.onScanWindowEnd = () {
      _emitFromPipeline(DateTime.now(), forceResting: true);
    };
    _manager.onRestTick = () {
      _emitFromPipeline(DateTime.now(), forceResting: true);
    };
    _manager.onError = (_) {
      onStateChanged?.call(
        ScanState(
          status: ScanStatus.error,
          statusMessage: AppCopy.scanErrorMessage,
          protectionRequested: _protectionRequested,
        ),
        PipelineResult(
          snapshot: DetectionSnapshot(
            assessments: const [],
            capturedAt: DateTime.now(),
          ),
          scoring: const ScoringResult(
            level: RiskLevel.low,
            totalScore: 0,
            reasons: [],
          ),
        ),
      );
    };
  }

  Future<ScanPreflightFailure?> startProtection() async {
    _protectionRequested = true;
    _protectionStartedAt = DateTime.now();
    _consecutiveElevatedScans = 0;
    pipeline.reset();

    if (scannerMode == ScannerMode.auto && _runtime.isAndroid) {
      final preflight = await _runtime.ensureAndroidReady();
      if (!preflight.isOk) {
        return preflight.failure;
      }
    }

    await _manager.start();
    final now = DateTime.now();
    _emitFromPipeline(now, statusOverride: ScanStatus.scanning);
    return null;
  }

  Future<void> pauseProtection() async {
    _protectionRequested = false;
    _consecutiveElevatedScans = 0;
    await _manager.stop();
    pipeline.reset();
    onStateChanged?.call(
      const ScanState(
        status: ScanStatus.paused,
        protectionRequested: false,
      ),
      PipelineResult(
        snapshot: DetectionSnapshot(
          assessments: const [],
          capturedAt: DateTime.now(),
        ),
        scoring: const ScoringResult(
          level: RiskLevel.low,
          totalScore: 0,
          reasons: [],
        ),
      ),
    );
  }

  void _onBatch(List<RadioScanResult> results) {
    final now = DateTime.now();
    final signals = results
        .map(
          (r) => DetectedSignal(
            id: r.id,
            displayName: r.name,
            rssi: r.rssi,
            serviceIds: r.serviceUuids,
            manufacturerIds: r.manufacturerIds,
            seenAt: r.observedAt,
            isConnectable: r.isConnectable,
          ),
        )
        .toList();
    final result = pipeline.processBatch(signals, now);
    _emitFromPipeline(
      now,
      pipelineResult: result,
      fromScanBatch: true,
    );
  }

  void _emitFromPipeline(
    DateTime now, {
    ScanStatus? statusOverride,
    bool forceResting = false,
    PipelineResult? pipelineResult,
    bool fromScanBatch = false,
  }) {
    final result = pipelineResult ?? pipeline.expireAndEvaluate(now);
    final scoring = result.scoring;
    final rawElevated =
        scoring.level == RiskLevel.medium || scoring.level == RiskLevel.high;

    // Only real radio batches count toward consecutive elevated scans.
    // Rest/window re-evaluation may still clear the counter when risk drops.
    if (fromScanBatch) {
      if (rawElevated) {
        _consecutiveElevatedScans++;
      } else {
        _consecutiveElevatedScans = 0;
      }
    } else if (!rawElevated) {
      _consecutiveElevatedScans = 0;
    }

    final pastGrace = _protectionStartedAt != null &&
        now.difference(_protectionStartedAt!) >= _startupGraceDuration;
    final alertConfirmed =
        pastGrace && _consecutiveElevatedScans >= _requiredElevatedScans;

    ScanStatus status;
    if (statusOverride != null) {
      status = statusOverride;
    } else if (forceResting && !_manager.inScanWindow) {
      status = alertConfirmed && rawElevated
          ? ScanStatus.possibleRiskDetected
          : ScanStatus.resting;
    } else if (alertConfirmed && rawElevated) {
      status = ScanStatus.possibleRiskDetected;
    } else if (rawElevated && !alertConfirmed) {
      status = ScanStatus.confirmingRisk;
    } else if (_manager.inScanWindow) {
      status = ScanStatus.scanning;
    } else {
      status = ScanStatus.resting;
    }

    onStateChanged?.call(
      ScanState(
        status: status,
        riskLevel:
            alertConfirmed && rawElevated ? scoring.level : RiskLevel.low,
        score: alertConfirmed && rawElevated ? scoring.totalScore : 0,
        reasons: alertConfirmed && rawElevated ? scoring.reasons : const [],
        protectionRequested: _protectionRequested,
        isDemoMode: isDemoMode,
        lastCheckedAt: now,
      ),
      result,
    );
  }

  void simulateHighRiskBatch(List<RadioScanResult> batch) {
    _protectionStartedAt = DateTime.now().subtract(
      _startupGraceDuration + const Duration(seconds: 1),
    );
    _consecutiveElevatedScans = _requiredElevatedScans - 1;
    _onBatch(batch);
  }
}

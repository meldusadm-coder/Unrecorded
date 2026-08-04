import '../features/scan/scan_state.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'scan_preflight_failure.dart';

/// Why background protection is not running when user intent was ON.
enum BackgroundProtectionStoppedReason {
  none,
  stoppedByAndroid,
  blocked,
  explicitNotificationStop,
  cancelledBeforeStart,
  protocolUnavailable,
}

/// Task-local scanner phase for ownership-capable snapshots.
enum BackgroundScannerPhase {
  starting,
  scanning,
  resting,
  blocked,
  stopping,
  stopped,
}

/// Outcome of a notification Stop protocol transaction.
enum StopTransactionOutcome {
  confirmed,
  persistenceUncertain,
  rejected,
  notAttempted,
}

/// Safe task-isolate → main-isolate state. Never includes BLE names, MACs,
/// stable keys, or raw scan payloads.
class BackgroundProtectionSnapshot {
  const BackgroundProtectionSnapshot({
    required this.status,
    required this.riskLevel,
    required this.score,
    required this.reasonLabels,
    required this.possibleRiskCount,
    required this.otherNearbyCount,
    this.lastCheckedAt,
    required this.isDemoMode,
    required this.serviceRunning,
    this.stoppedReason = BackgroundProtectionStoppedReason.none,
    this.sessionId,
    this.sessionEpoch,
    this.engineIncarnationId,
    this.scannerLeaseId,
    this.protocolRevision,
    this.messageSequence,
    this.scannerPhase,
    this.taskBlockedCause,
    this.stopTransactionOutcome,
    this.stopConfirmedRevision,
    this.scannerStopOutcome,
    this.leaseReleased,
    this.riskEpisodeId,
  });

  final ScanStatus status;
  final RiskLevel riskLevel;
  final int score;
  final List<String> reasonLabels;
  final int possibleRiskCount;
  final int otherNearbyCount;
  final DateTime? lastCheckedAt;
  final bool isDemoMode;
  final bool serviceRunning;
  final BackgroundProtectionStoppedReason stoppedReason;

  final String? sessionId;
  final int? sessionEpoch;
  final String? engineIncarnationId;
  final String? scannerLeaseId;
  final int? protocolRevision;
  final int? messageSequence;
  final BackgroundScannerPhase? scannerPhase;
  final ScanPreflightFailure? taskBlockedCause;
  final StopTransactionOutcome? stopTransactionOutcome;
  final int? stopConfirmedRevision;
  final String? scannerStopOutcome;
  final bool? leaseReleased;
  final String? riskEpisodeId;

  /// Ownership-capable messages require full session/lease identity.
  bool get isOwnershipCapable =>
      sessionId != null &&
      sessionEpoch != null &&
      engineIncarnationId != null &&
      scannerLeaseId != null;

  Map<String, Object?> toJson() => {
        'type': 'background_protection_snapshot',
        'status': status.name,
        'riskLevel': riskLevel.name,
        'score': score,
        'reasonLabels': reasonLabels,
        'possibleRiskCount': possibleRiskCount,
        'otherNearbyCount': otherNearbyCount,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
        'isDemoMode': isDemoMode,
        'serviceRunning': serviceRunning,
        'stoppedReason': stoppedReason.name,
        'sessionId': sessionId,
        'sessionEpoch': sessionEpoch,
        'engineIncarnationId': engineIncarnationId,
        'scannerLeaseId': scannerLeaseId,
        'protocolRevision': protocolRevision,
        'messageSequence': messageSequence,
        'scannerPhase': scannerPhase?.name,
        'taskBlockedCause': taskBlockedCause?.name,
        'stopTransactionOutcome': stopTransactionOutcome?.name,
        'stopConfirmedRevision': stopConfirmedRevision,
        'scannerStopOutcome': scannerStopOutcome,
        'leaseReleased': leaseReleased,
        'riskEpisodeId': riskEpisodeId,
      };

  static BackgroundProtectionSnapshot? fromJson(Object? data) {
    if (data is! Map) return null;
    if (data['type'] != 'background_protection_snapshot') return null;

    final statusName = data['status'] as String?;
    final riskName = data['riskLevel'] as String?;
    if (statusName == null || riskName == null) return null;

    final status = ScanStatus.values.asNameMap()[statusName];
    final riskLevel = RiskLevel.values.asNameMap()[riskName];
    if (status == null || riskLevel == null) return null;

    final stoppedName = data['stoppedReason'] as String? ?? 'none';
    final stoppedReason =
        BackgroundProtectionStoppedReason.values.asNameMap()[stoppedName] ??
            BackgroundProtectionStoppedReason.none;

    final lastCheckedRaw = data['lastCheckedAt'] as String?;
    DateTime? lastCheckedAt;
    if (lastCheckedRaw != null) {
      lastCheckedAt = DateTime.tryParse(lastCheckedRaw);
    }

    final phaseName = data['scannerPhase'] as String?;
    final scannerPhase = phaseName == null
        ? null
        : BackgroundScannerPhase.values.asNameMap()[phaseName];

    final blockedName = data['taskBlockedCause'] as String?;
    final taskBlockedCause = blockedName == null
        ? null
        : ScanPreflightFailure.values.asNameMap()[blockedName];

    final stopOutcomeName = data['stopTransactionOutcome'] as String?;
    final stopTransactionOutcome = stopOutcomeName == null
        ? null
        : StopTransactionOutcome.values.asNameMap()[stopOutcomeName];

    return BackgroundProtectionSnapshot(
      status: status,
      riskLevel: riskLevel,
      score: (data['score'] as num?)?.toInt() ?? 0,
      reasonLabels:
          (data['reasonLabels'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      possibleRiskCount: (data['possibleRiskCount'] as num?)?.toInt() ?? 0,
      otherNearbyCount: (data['otherNearbyCount'] as num?)?.toInt() ?? 0,
      lastCheckedAt: lastCheckedAt,
      isDemoMode: data['isDemoMode'] as bool? ?? false,
      serviceRunning: data['serviceRunning'] as bool? ?? false,
      stoppedReason: stoppedReason,
      sessionId: data['sessionId'] as String?,
      sessionEpoch: (data['sessionEpoch'] as num?)?.toInt(),
      engineIncarnationId: data['engineIncarnationId'] as String?,
      scannerLeaseId: data['scannerLeaseId'] as String?,
      protocolRevision: (data['protocolRevision'] as num?)?.toInt(),
      messageSequence: (data['messageSequence'] as num?)?.toInt(),
      scannerPhase: scannerPhase,
      taskBlockedCause: taskBlockedCause,
      stopTransactionOutcome: stopTransactionOutcome,
      stopConfirmedRevision: (data['stopConfirmedRevision'] as num?)?.toInt(),
      scannerStopOutcome: data['scannerStopOutcome'] as String?,
      leaseReleased: data['leaseReleased'] as bool?,
      riskEpisodeId: data['riskEpisodeId'] as String?,
    );
  }

  /// Converts to a [ScanState] for UI mirroring (no per-signal detail).
  ScanState toScanState({bool protectionRequested = true}) {
    return ScanState(
      status: status,
      riskLevel: riskLevel,
      score: score,
      reasons: reasonLabels,
      possibleRiskSignals: const [],
      otherNearbySignals: const [],
      lastCheckedAt: lastCheckedAt,
      protectionRequested: protectionRequested,
      isDemoMode: isDemoMode,
    );
  }
}

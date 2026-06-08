import '../features/scan/scan_state.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

/// Why background protection is not running when user intent was ON.
enum BackgroundProtectionStoppedReason {
  none,
  stoppedByAndroid,
  blocked,
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

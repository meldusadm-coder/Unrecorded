import 'recent_risk_reason.dart';
import 'recent_risk_window.dart';
import 'risk_level.dart';

/// Locally persisted latest possible-risk reminder (not a history log).
class RecentRiskEvent {
  const RecentRiskEvent({
    required this.noticedAt,
    required this.riskLevel,
    this.reasons = const [],
    this.acknowledged = false,
  });

  final DateTime noticedAt;
  final RiskLevel riskLevel;
  final List<RecentRiskReason> reasons;
  final bool acknowledged;

  bool isActiveReminder(RecentRiskWindow window, DateTime now) {
    final duration = window.duration;
    if (duration == null || acknowledged) return false;
    return now.difference(noticedAt) < duration;
  }

  RecentRiskEvent copyWith({
    DateTime? noticedAt,
    RiskLevel? riskLevel,
    List<RecentRiskReason>? reasons,
    bool? acknowledged,
  }) {
    return RecentRiskEvent(
      noticedAt: noticedAt ?? this.noticedAt,
      riskLevel: riskLevel ?? this.riskLevel,
      reasons: reasons ?? this.reasons,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, Object?> toJson() => {
        'noticedAt': noticedAt.toIso8601String(),
        'riskLevel': riskLevel.name,
        'reasons': reasons.map((r) => r.name).toList(),
        'acknowledged': acknowledged,
      };

  static RecentRiskEvent? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;

    final noticedRaw = json['noticedAt'];
    if (noticedRaw is! String) return null;
    final noticedAt = DateTime.tryParse(noticedRaw);
    if (noticedAt == null) return null;

    final levelRaw = json['riskLevel'];
    if (levelRaw is! String) return null;
    final riskLevel = _riskLevelFromName(levelRaw);
    if (riskLevel == null) return null;

    final reasonsRaw = json['reasons'];
    final reasons = <RecentRiskReason>[];
    if (reasonsRaw is List) {
      for (final item in reasonsRaw) {
        if (item is! String) continue;
        final reason = recentRiskReasonFromStorage(item);
        if (reason != null) reasons.add(reason);
      }
    }

    final acknowledged = json['acknowledged'] == true;

    return RecentRiskEvent(
      noticedAt: noticedAt,
      riskLevel: riskLevel,
      reasons: reasons,
      acknowledged: acknowledged,
    );
  }

  static RiskLevel? _riskLevelFromName(String name) {
    for (final level in RiskLevel.values) {
      if (level.name == name) return level;
    }
    return null;
  }
}

/// Whether a recent-risk reminder should be shown (live-alert check separate).
bool isRecentRiskReminderVisible({
  required RecentRiskEvent? event,
  required RecentRiskWindow window,
  required bool hasLiveAlert,
  required DateTime now,
}) {
  if (hasLiveAlert || event == null) return false;
  return event.isActiveReminder(window, now);
}

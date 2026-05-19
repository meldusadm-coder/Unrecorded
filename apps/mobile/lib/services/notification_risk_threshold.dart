import 'package:unrecorded_core/unrecorded_core.dart';

/// Minimum assessed risk before a local notification is shown.
enum NotificationRiskThreshold {
  mediumAndHigh,
  highOnly,
}

extension NotificationRiskThresholdStorage on NotificationRiskThreshold {
  String get storageKey => name;

  static NotificationRiskThreshold fromStorage(String? value) {
    return NotificationRiskThreshold.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationRiskThreshold.mediumAndHigh,
    );
  }

  String get label {
    switch (this) {
      case NotificationRiskThreshold.mediumAndHigh:
        return 'Medium and high';
      case NotificationRiskThreshold.highOnly:
        return 'High only';
    }
  }
}

/// Whether [level] meets the user's notification threshold.
bool notificationThresholdMet(
  RiskLevel level,
  NotificationRiskThreshold threshold,
) {
  switch (threshold) {
    case NotificationRiskThreshold.highOnly:
      return level == RiskLevel.high;
    case NotificationRiskThreshold.mediumAndHigh:
      return level == RiskLevel.medium || level == RiskLevel.high;
  }
}

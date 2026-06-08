/// User-configurable window for showing a recent possible-risk reminder.
enum RecentRiskWindow {
  off,
  m15,
  m30,
  h1,
  h3,
}

extension RecentRiskWindowX on RecentRiskWindow {
  static const defaultWindow = RecentRiskWindow.m30;

  /// Null when [RecentRiskWindow.off].
  Duration? get duration => switch (this) {
        RecentRiskWindow.off => null,
        RecentRiskWindow.m15 => const Duration(minutes: 15),
        RecentRiskWindow.m30 => const Duration(minutes: 30),
        RecentRiskWindow.h1 => const Duration(hours: 1),
        RecentRiskWindow.h3 => const Duration(hours: 3),
      };

  String get storageKey => name;

  String get label => switch (this) {
        RecentRiskWindow.off => 'Off',
        RecentRiskWindow.m15 => '15 minutes',
        RecentRiskWindow.m30 => '30 minutes',
        RecentRiskWindow.h1 => '1 hour',
        RecentRiskWindow.h3 => '3 hours',
      };

  static RecentRiskWindow fromStorage(String? key) {
    if (key == null || key.isEmpty) return defaultWindow;
    for (final value in RecentRiskWindow.values) {
      if (value.storageKey == key) return value;
    }
    return defaultWindow;
  }
}

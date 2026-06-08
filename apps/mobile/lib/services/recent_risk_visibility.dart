import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/scan_state.dart';
import 'recent_risk_controller.dart';
import 'scanner_provider.dart';

final recentRiskVisibleProvider = Provider<RecentRiskEvent?>((ref) {
  final recent = ref.watch(recentRiskControllerProvider);
  final scanStatus = ref.watch(scanControllerProvider).status;
  final now = ref.watch(clockProvider)();
  final hasLiveAlert = scanStatus == ScanStatus.possibleRiskDetected;
  if (!isRecentRiskReminderVisible(
    event: recent.event,
    window: recent.window,
    hasLiveAlert: hasLiveAlert,
    now: now,
  )) {
    return null;
  }
  return recent.event;
});

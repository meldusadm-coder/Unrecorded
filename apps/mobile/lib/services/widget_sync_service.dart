import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/scan_state.dart';
import 'recent_risk_controller.dart';
import 'scanner_provider.dart';

const _keyStatus = 'widget_status';
const _keySecondary = 'widget_secondary';
const _keyLastChecked = 'widget_last_checked';

class WidgetSyncService {
  const WidgetSyncService();

  Future<void> syncFromState(
    ScanState state, {
    bool recentRiskVisible = false,
  }) async {
    try {
      final lines = linesForState(state, recentRiskVisible: recentRiskVisible);
      await HomeWidget.saveWidgetData<String>(_keyStatus, lines.$1);
      await HomeWidget.saveWidgetData<String>(_keySecondary, lines.$2);
      await HomeWidget.saveWidgetData<String>(
        _keyLastChecked,
        state.lastCheckedAt?.toIso8601String() ?? '',
      );
      await HomeWidget.updateWidget(
        name: 'UnrecordedWidgetProvider',
        androidName: 'UnrecordedWidgetProvider',
      );
    } catch (_) {}
  }

  @visibleForTesting
  (String, String) linesForState(
    ScanState state, {
    required bool recentRiskVisible,
  }) {
    if (state.status != ScanStatus.possibleRiskDetected && recentRiskVisible) {
      return (
        AppCopy.widgetPossibleRiskRecent,
        AppCopy.widgetOpenAppToView,
      );
    }

    switch (state.status) {
      case ScanStatus.scanning:
      case ScanStatus.confirmingRisk:
        if (state.hasElevatedRisk) {
          return (AppCopy.widgetPossibleRisk, _lastCheckedLine(state));
        }
        return (
          AppCopy.widgetScanningActive,
          state.riskLevel == RiskLevel.low
              ? AppCopy.widgetNoObviousRisk
              : _lastCheckedLine(state),
        );
      case ScanStatus.resting:
        return (AppCopy.widgetCheckingShortly, _lastCheckedLine(state));
      case ScanStatus.possibleRiskDetected:
        return (AppCopy.widgetPossibleRisk, _lastCheckedLine(state));
      case ScanStatus.permissionDenied:
      case ScanStatus.permissionPermanentlyDenied:
      case ScanStatus.bluetoothOff:
      case ScanStatus.bluetoothUnsupported:
        return (AppCopy.widgetPermissionsNeeded, 'Open app to fix');
      case ScanStatus.paused:
      case ScanStatus.idle:
        return (AppCopy.widgetScanningPaused, 'Tap to open');
      case ScanStatus.starting:
        return (AppCopy.widgetScanningActive, 'Starting…');
      case ScanStatus.error:
        return ('Scan issue', 'Tap to open app');
    }
  }

  String _lastCheckedLine(ScanState state) {
    final t = state.lastCheckedAt;
    if (t == null) return AppCopy.widgetNoObviousRisk;
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Checked just now';
    if (diff.inMinutes < 60) return 'Checked ${diff.inMinutes}m ago';
    return 'Checked ${diff.inHours}h ago';
  }
}

final widgetSyncServiceProvider = Provider<WidgetSyncService>((ref) {
  final service = const WidgetSyncService();

  void syncWidget() {
    final scanState = ref.read(scanControllerProvider);
    final recentState = ref.read(recentRiskControllerProvider);
    final now = ref.read(clockProvider)();
    final recentRiskVisible = isRecentRiskReminderVisible(
      event: recentState.event,
      window: recentState.window,
      hasLiveAlert: scanState.status == ScanStatus.possibleRiskDetected,
      now: now,
    );
    unawaited(
      service.syncFromState(
        scanState,
        recentRiskVisible: recentRiskVisible,
      ),
    );
  }

  ref.listen(scanControllerProvider, (_, __) => syncWidget());
  ref.listen(recentRiskControllerProvider, (_, __) => syncWidget());
  ref.listen(widgetSyncTriggerProvider, (_, __) => syncWidget());

  return service;
});

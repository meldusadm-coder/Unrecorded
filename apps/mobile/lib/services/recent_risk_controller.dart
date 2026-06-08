import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'recent_risk_prefs.dart';

/// Injectable clock for deterministic expiry tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class RecentRiskState {
  const RecentRiskState({
    this.event,
    this.window = RecentRiskWindowX.defaultWindow,
  });

  final RecentRiskEvent? event;
  final RecentRiskWindow window;
}

class RecentRiskController extends StateNotifier<RecentRiskState> {
  RecentRiskController({
    required DateTime Function() now,
    Future<RecentRiskPrefs> Function()? prefsFactory,
  })  : _now = now,
        _prefsFactory = prefsFactory ?? RecentRiskPrefs.load,
        super(const RecentRiskState()) {
    unawaited(_load());
  }

  /// Synchronous initial state for widget/unit tests (no load, no expiry timer).
  @visibleForTesting
  RecentRiskController.forTesting(
    super.initialState, {
    DateTime Function()? now,
    Future<RecentRiskPrefs> Function()? prefsFactory,
  })  : _now = now ?? DateTime.now,
        _prefsFactory = prefsFactory ?? RecentRiskPrefs.load;

  final DateTime Function() _now;
  final Future<RecentRiskPrefs> Function() _prefsFactory;
  int _generation = 0;
  Timer? _expiryTimer;

  Future<void> _load() async {
    final gen = _generation;
    final prefs = await _prefsFactory();
    if (!mounted || gen != _generation) return;
    state = RecentRiskState(event: prefs.event, window: prefs.window);
    _scheduleExpiryTimer();
  }

  Future<void> reload() => _load();

  Future<void> recordPossibleRisk({
    required RiskLevel riskLevel,
    required List<RecentRiskReason> reasons,
  }) async {
    if (state.window == RecentRiskWindow.off) return;

    _generation++;
    final event = RecentRiskEvent(
      noticedAt: _now(),
      riskLevel: riskLevel,
      reasons: reasons,
      acknowledged: false,
    );
    final prefs = await _prefsFactory();
    await prefs.setEvent(event);
    if (!mounted) return;
    state = RecentRiskState(event: event, window: state.window);
    _scheduleExpiryTimer();
  }

  Future<void> acknowledge() async {
    final current = state.event;
    if (current == null || current.acknowledged) return;

    _generation++;
    final prefs = await _prefsFactory();
    await prefs.acknowledge();
    if (!mounted) return;
    state = RecentRiskState(
      event: current.copyWith(acknowledged: true),
      window: state.window,
    );
    _cancelExpiryTimer();
  }

  Future<void> setWindow(RecentRiskWindow window) async {
    _generation++;
    final prefs = await _prefsFactory();
    if (window == RecentRiskWindow.off) {
      await prefs.setWindowOffAndClear();
      if (!mounted) return;
      state = const RecentRiskState(
        window: RecentRiskWindow.off,
        event: null,
      );
      _cancelExpiryTimer();
      return;
    }

    await prefs.setWindow(window);
    if (!mounted) return;
    state = RecentRiskState(event: state.event, window: window);
    _scheduleExpiryTimer();
  }

  Future<void> clear() async {
    _generation++;
    final prefs = await _prefsFactory();
    await prefs.clearEvent();
    if (!mounted) return;
    state = RecentRiskState(event: null, window: state.window);
    _cancelExpiryTimer();
  }

  void _scheduleExpiryTimer() {
    _cancelExpiryTimer();
    final event = state.event;
    final duration = state.window.duration;
    if (event == null || duration == null || event.acknowledged) return;

    final expiresAt = event.noticedAt.add(duration);
    final delay = expiresAt.difference(_now());
    if (delay.isNegative) {
      _emitExpiryTick();
      return;
    }

    _expiryTimer = Timer(delay, _emitExpiryTick);
  }

  void _emitExpiryTick() {
    if (!mounted) return;
    state = RecentRiskState(event: state.event, window: state.window);
  }

  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  @override
  void dispose() {
    _cancelExpiryTimer();
    if (mounted) {
      super.dispose();
    }
  }
}

final recentRiskControllerProvider =
    StateNotifierProvider<RecentRiskController, RecentRiskState>((ref) {
  return RecentRiskController(now: ref.watch(clockProvider));
});

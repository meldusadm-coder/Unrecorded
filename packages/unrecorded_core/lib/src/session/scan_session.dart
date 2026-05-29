import '../models/detected_signal.dart';
import 'signal_observation.dart';
import 'tracked_signal.dart';

/// In-memory merge of observations across scan batches (not persisted).
class ScanSession {
  ScanSession({this.staleTtl = const Duration(seconds: 60)});

  final Duration staleTtl;
  final Map<String, TrackedSignal> _tracked = {};

  void observe(DetectedSignal signal) {
    observeObservation(SignalObservation.fromDetectedSignal(signal));
  }

  void observeObservation(SignalObservation obs) {
    final existing = _tracked[obs.stableKey];
    if (existing != null) {
      existing.mergeObservation(obs);
    } else {
      _tracked[obs.stableKey] = TrackedSignal.fromObservation(obs);
    }
  }

  void observeAll(Iterable<DetectedSignal> signals) {
    for (final signal in signals) {
      observe(signal);
    }
  }

  /// Removes signals not seen since [now] - [staleTtl].
  List<String> expireStale(DateTime now) {
    final expired = <String>[];
    _tracked.removeWhere((key, tracked) {
      if (now.difference(tracked.lastSeenAt) > staleTtl) {
        expired.add(key);
        return true;
      }
      return false;
    });
    return expired;
  }

  List<TrackedSignal> activeSignals(DateTime now) {
    expireStale(now);
    return _tracked.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  }

  void reset() => _tracked.clear();

  int get count => _tracked.length;
}

import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/signal_ui_model.dart';

/// Maps [DetectionAssessment] to [SignalUiModel] for UI layers.
class SignalUiMapper {
  const SignalUiMapper();

  List<SignalUiModel> fromAssessments(List<DetectionAssessment> assessments) {
    return assessments.map(_map).toList();
  }

  (List<SignalUiModel> risk, List<SignalUiModel> other) partition(
    List<DetectionAssessment> assessments,
  ) {
    final risk = <SignalUiModel>[];
    final other = <SignalUiModel>[];
    for (final a in assessments) {
      final ui = _map(a);
      if (a.contributesToRisk) {
        risk.add(ui);
      } else {
        other.add(ui);
      }
    }
    return (risk, other);
  }

  SignalUiModel _map(DetectionAssessment assessment) {
    final signal = assessment.signal;
    final title = signal.displayName?.trim().isNotEmpty == true
        ? signal.displayName!
        : 'Nearby device';

    return SignalUiModel(
      title: title,
      categoryLabel: assessment.category.displayLabel,
      confidenceLabel: assessment.confidenceBand.label,
      evidenceLabels: assessment.evidence.map((e) => e.label).toList(),
      lastSeenLabel: _lastSeen(signal.lastSeenAt),
      signalStrengthLabel: _rssiLabel(signal.lastRssi),
      contributesToRisk: assessment.contributesToRisk,
    );
  }

  String _lastSeen(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 10) return 'Last seen just now';
    if (diff.inMinutes < 1) return 'Last seen ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    return 'Last seen ${diff.inHours}h ago';
  }

  String _rssiLabel(int? rssi) {
    if (rssi == null) return 'Signal strength unknown';
    if (rssi >= -55) return 'Strong nearby signal';
    if (rssi >= -68) return 'Moderate nearby signal';
    return 'Weak nearby signal';
  }
}

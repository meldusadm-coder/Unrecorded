import '../classification/device_signal_category.dart';
import '../session/tracked_signal.dart';
import 'benign_name_matcher.dart';
import 'confidence_band.dart';
import 'detection_assessment.dart';
import 'detection_evidence.dart';
import 'signature_matcher.dart';

/// Assesses tracked signals: matching, evidence, classification (no scoring).
class DetectionEngine {
  DetectionEngine({SignatureMatcher? matcher})
      : _matcher = matcher ?? const SignatureMatcher();

  final SignatureMatcher _matcher;

  List<DetectionAssessment> assessAll(List<TrackedSignal> active) {
    return active.map(_assess).toList();
  }

  DetectionAssessment _assess(TrackedSignal tracked) {
    final detected = tracked.toDetectedSignal();
    final evidence = <DetectionEvidence>[];

    // Suspicious catalogue match first — benign cannot suppress this.
    final match = _matcher.bestMatch(detected);
    if (match != null) {
      evidence.add(
        DetectionEvidence(
          kind: switch (match.kind) {
            SignatureMatchKind.name => DetectionEvidenceKind.nameMatch,
            SignatureMatchKind.serviceUuid =>
              DetectionEvidenceKind.serviceUuidHint,
            SignatureMatchKind.macPrefix =>
              DetectionEvidenceKind.addressPrefixHint,
          },
          label: match.explanation,
        ),
      );
    }

    final vendorHint = _matcher.vendorHintFromId(tracked.id);
    if (match == null && vendorHint != null && tracked.normalizedMac != null) {
      evidence.add(
        DetectionEvidence(
          kind: DetectionEvidenceKind.addressPrefixHint,
          label: vendorHint,
        ),
      );
    }

    if (tracked.sightingCount >= 2 && match != null) {
      evidence.add(
        DetectionEvidence(
          kind: DetectionEvidenceKind.repeatedSighting,
          label: tracked.sightingCount >= 4
              ? 'Seen repeatedly nearby (${tracked.sightingCount} times)'
              : 'Seen more than once nearby',
        ),
      );
    }

    final rssi = tracked.smoothedRssi?.round() ?? tracked.lastRssi;
    if (rssi != null && match != null) {
      if (rssi >= -55) {
        evidence.add(
          const DetectionEvidence(
            kind: DetectionEvidenceKind.strongSignal,
            label:
                'Strong nearby signal (rough proximity only, not exact distance)',
          ),
        );
      }
    }

    if (tracked.everConnectable && match != null) {
      evidence.add(
        const DetectionEvidence(
          kind: DetectionEvidenceKind.connectable,
          label: 'Device is connectable, which may mean it is in use nearby',
        ),
      );
    }

    DeviceSignalCategory category;
    var contributes = false;
    ConfidenceBand band = ConfidenceBand.low;

    if (match != null) {
      category = DeviceSignalCategory.possibleRecordingWearable;
      contributes = true;
      band = switch (match.kind) {
        SignatureMatchKind.name ||
        SignatureMatchKind.serviceUuid =>
          tracked.sightingCount >= 2
              ? ConfidenceBand.elevated
              : ConfidenceBand.moderate,
        SignatureMatchKind.macPrefix => ConfidenceBand.moderate,
      };
    } else if (vendorHint != null && tracked.normalizedMac != null) {
      category = DeviceSignalCategory.possibleRecordingWearable;
      contributes = true;
      band = ConfidenceBand.moderate;
    } else {
      final benign = matchBenignCategory(tracked.displayName);
      if (benign != null) {
        category = _categoryFromBenign(benign);
        evidence.add(
          DetectionEvidence(
            kind: DetectionEvidenceKind.benignName,
            label:
                'Name suggests a common ${category.displayLabel.toLowerCase()}',
          ),
        );
      } else {
        category = DeviceSignalCategory.unknown;
        if (tracked.displayName == null) {
          evidence.add(
            const DetectionEvidence(
              kind: DetectionEvidenceKind.unknown,
              label: 'Unknown nearby signal',
            ),
          );
        }
      }
    }

    return DetectionAssessment(
      signal: tracked,
      category: category,
      matchedSignature: match?.signature,
      evidence: evidence,
      confidenceBand: band,
      contributesToRisk: contributes,
      primaryMatchKind: match?.kind,
    );
  }

  DeviceSignalCategory _categoryFromBenign(BenignDeviceCategory benign) {
    return switch (benign) {
      BenignDeviceCategory.audio => DeviceSignalCategory.likelyAudio,
      BenignDeviceCategory.input => DeviceSignalCategory.likelyInput,
      BenignDeviceCategory.mediaTv => DeviceSignalCategory.likelyMediaTv,
      BenignDeviceCategory.wearableFitness =>
        DeviceSignalCategory.likelyWearableFitness,
      BenignDeviceCategory.vehicle => DeviceSignalCategory.likelyVehicle,
    };
  }
}

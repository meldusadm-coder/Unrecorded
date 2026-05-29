import '../models/detected_signal.dart';
import 'detection_signature.dart';
import 'detection_signatures.dart';

/// How a catalogue entry matched a signal.
enum SignatureMatchKind {
  name,
  serviceUuid,
  macPrefix,
}

/// Result of matching a [DetectedSignal] against the local catalogue.
class SignatureMatch {
  const SignatureMatch({
    required this.signature,
    required this.kind,
    required this.score,
  });

  final DetectionSignature signature;
  final SignatureMatchKind kind;
  final int score;

  String get explanation {
    return switch (kind) {
      SignatureMatchKind.macPrefix => signature.explanationForMacPrefix(),
      _ => signature.matchExplanation,
    };
  }
}

/// Shared local matching for scoring and classification.
class SignatureMatcher {
  const SignatureMatcher({this.signatures = detectionSignatures});

  final List<DetectionSignature> signatures;

  /// Whether [name] matches a benign peripheral keyword.
  static bool isBenignName(String? name) {
    final lower = name?.toLowerCase();
    if (lower == null) return false;
    for (final kw in benignNameKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  /// Best catalogue match for [signal], or null if none.
  ///
  /// Does not apply benign suppression — callers assess benign after matching.
  SignatureMatch? bestMatch(DetectedSignal signal) {
    SignatureMatch? best;
    for (final signature in signatures) {
      final nameMatch = _matchName(signal.displayName, signature);
      if (nameMatch != null && (best == null || nameMatch.score > best.score)) {
        best = nameMatch;
      }

      final uuidMatch = _matchServiceUuids(signal.serviceIds, signature);
      if (uuidMatch != null && (best == null || uuidMatch.score > best.score)) {
        best = uuidMatch;
      }

      final macMatch = _matchMacPrefix(signal.id, signature);
      if (macMatch != null && (best == null || macMatch.score > best.score)) {
        best = macMatch;
      }
    }
    return best;
  }

  bool hasMatch(DetectedSignal signal) => bestMatch(signal) != null;

  /// User-facing vendor hint from MAC prefix, independent of scoring weight.
  String? vendorHintFromId(String id) {
    final normalized = normalizeMac(id);
    if (normalized == null || normalized.length < 6) return null;

    DetectionSignature? bestSignature;
    var bestPrefixLen = 0;
    for (final signature in signatures) {
      for (final prefix in signature.macPrefixHints) {
        if (normalized.startsWith(prefix) && prefix.length > bestPrefixLen) {
          bestSignature = signature;
          bestPrefixLen = prefix.length;
        }
      }
    }
    if (bestSignature == null) return null;
    return '${bestSignature.brandFamily} (address prefix hint — not proof)';
  }

  SignatureMatch? _matchName(String? name, DetectionSignature signature) {
    final lower = name?.toLowerCase();
    if (lower == null) return null;
    for (final kw in signature.nameKeywords) {
      if (lower.contains(kw)) {
        return SignatureMatch(
          signature: signature,
          kind: SignatureMatchKind.name,
          score: signature.confidenceWeight,
        );
      }
    }
    return null;
  }

  SignatureMatch? _matchServiceUuids(
    List<String> serviceIds,
    DetectionSignature signature,
  ) {
    if (signature.serviceUuidHints.isEmpty || serviceIds.isEmpty) {
      return null;
    }
    final normalizedHints = signature.serviceUuidHints
        .map(normalizeServiceUuid)
        .whereType<String>()
        .toSet();
    for (final id in serviceIds) {
      final normalized = normalizeServiceUuid(id);
      if (normalized != null && normalizedHints.contains(normalized)) {
        return SignatureMatch(
          signature: signature,
          kind: SignatureMatchKind.serviceUuid,
          score: signature.confidenceWeight,
        );
      }
    }
    return null;
  }

  SignatureMatch? _matchMacPrefix(
    String id,
    DetectionSignature signature,
  ) {
    final normalized = normalizeMac(id);
    if (normalized == null || signature.macPrefixHints.isEmpty) return null;

    String? bestPrefix;
    for (final prefix in signature.macPrefixHints) {
      if (normalized.startsWith(prefix) &&
          (bestPrefix == null || prefix.length > bestPrefix.length)) {
        bestPrefix = prefix;
      }
    }
    if (bestPrefix == null) return null;

    final macScore = signature.confidenceWeight >= 5
        ? signature.confidenceWeight - 5
        : signature.confidenceWeight;
    return SignatureMatch(
      signature: signature,
      kind: SignatureMatchKind.macPrefix,
      score: macScore,
    );
  }

  /// Returns lowercase hex without separators if [id] looks like a MAC address.
  static String? normalizeMac(String id) {
    final trimmed = id.trim().toLowerCase();
    if (RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$').hasMatch(trimmed)) {
      return trimmed.replaceAll(':', '');
    }
    if (RegExp(r'^([0-9a-f]{2}-){5}[0-9a-f]{2}$').hasMatch(trimmed)) {
      return trimmed.replaceAll('-', '');
    }
    final hexOnly = trimmed.replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hexOnly.length >= 12 && RegExp(r'^[0-9a-f]+$').hasMatch(hexOnly)) {
      return hexOnly.substring(0, 12);
    }
    return null;
  }

  /// Normalizes BLE service UUID strings for comparison.
  static String? normalizeServiceUuid(String uuid) {
    final trimmed = uuid.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final short = RegExp(r'^[0-9a-f]{4}$').hasMatch(trimmed);
    if (short) return trimmed;

    final full = trimmed.replaceAll('-', '');
    if (RegExp(r'^[0-9a-f]{32}$').hasMatch(full)) {
      return full.substring(4, 8);
    }
    if (RegExp(r'^[0-9a-f]{8}$').hasMatch(full)) {
      return full.substring(4, 8);
    }
    return trimmed;
  }
}

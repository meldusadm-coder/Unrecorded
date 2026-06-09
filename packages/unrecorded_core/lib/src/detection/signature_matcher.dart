import '../models/detected_signal.dart';
import 'detection_signature.dart';
import 'detection_signatures.dart';

/// How a catalogue entry matched a signal.
enum SignatureMatchKind {
  name,
  serviceUuid,
  manufacturer,
  macPrefix,
}

/// Result of matching a [DetectedSignal] against one catalogue entry.
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

/// All match kinds for one signature against a signal.
class SignatureMatchSet {
  const SignatureMatchSet({
    required this.signature,
    this.name,
    this.serviceUuid,
    this.manufacturer,
    this.macPrefix,
  });

  final DetectionSignature signature;
  final SignatureMatch? name;
  final SignatureMatch? serviceUuid;
  final SignatureMatch? manufacturer;
  final SignatureMatch? macPrefix;

  bool get hasAnyMatch =>
      name != null ||
      serviceUuid != null ||
      manufacturer != null ||
      macPrefix != null;

  /// Strongest match for this signature (kind precedence, not raw score).
  SignatureMatch? get best => name ?? serviceUuid ?? manufacturer ?? macPrefix;

  Iterable<SignatureMatch> get allMatches sync* {
    if (name != null) yield name!;
    if (serviceUuid != null) yield serviceUuid!;
    if (manufacturer != null) yield manufacturer!;
    if (macPrefix != null) yield macPrefix!;
  }
}

/// Catalogue-wide match result for one signal.
class CatalogueMatchResult {
  const CatalogueMatchResult({
    required this.perSignature,
    this.primary,
  });

  final List<SignatureMatchSet> perSignature;
  final SignatureMatch? primary;
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

  /// Whether [address] is a canonical public unicast MAC suitable for prefix hints.
  static bool shouldConsiderAddressPrefix(String? address) {
    if (address == null || address.trim().isEmpty) return false;

    final trimmed = address.trim();
    if (RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }

    final normalized = normalizeMac(trimmed);
    if (normalized == null || normalized.length != 12) return false;

    final firstOctet = int.parse(normalized.substring(0, 2), radix: 16);
    if ((firstOctet & 0x01) != 0) return false;
    if ((firstOctet & 0x02) != 0) return false;
    return true;
  }

  /// All signature matches for [signal], with a precedence-ranked primary.
  CatalogueMatchResult matchCatalogue(DetectedSignal signal) {
    final sets = <SignatureMatchSet>[];
    for (final signature in signatures) {
      final set = _matchSignature(signal, signature);
      if (set.hasAnyMatch) sets.add(set);
    }
    return CatalogueMatchResult(
      perSignature: sets,
      primary: _bestAcrossSets(sets),
    );
  }

  /// Best catalogue match for [signal], or null if none.
  ///
  /// Ranked by kind precedence (name > service UUID > manufacturer > address
  /// prefix), not raw score. Does not apply benign suppression.
  SignatureMatch? bestMatch(DetectedSignal signal) =>
      matchCatalogue(signal).primary;

  bool hasMatch(DetectedSignal signal) => bestMatch(signal) != null;

  /// User-facing vendor hint from address prefix, independent of scoring weight.
  String? vendorHintFromId(String id) {
    if (!shouldConsiderAddressPrefix(id)) return null;

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

  SignatureMatchSet _matchSignature(
    DetectedSignal signal,
    DetectionSignature signature,
  ) {
    return SignatureMatchSet(
      signature: signature,
      name: _matchName(signal.displayName, signature),
      serviceUuid: _matchServiceUuids(signal.serviceIds, signature),
      manufacturer: _matchManufacturer(signal.manufacturerIds, signature),
      macPrefix: _matchMacPrefix(signal.id, signature),
    );
  }

  SignatureMatch? _bestAcrossSets(List<SignatureMatchSet> sets) {
    SignatureMatch? best;
    for (final set in sets) {
      final candidate = set.best;
      if (candidate == null) continue;
      if (best == null || _compareMatches(candidate, best) < 0) {
        best = candidate;
      }
    }
    return best;
  }

  int _compareMatches(SignatureMatch a, SignatureMatch b) {
    final rankA = _kindRank(a.kind);
    final rankB = _kindRank(b.kind);
    if (rankA != rankB) return rankA.compareTo(rankB);
    return b.score.compareTo(a.score);
  }

  static int _kindRank(SignatureMatchKind kind) => switch (kind) {
        SignatureMatchKind.name => 0,
        SignatureMatchKind.serviceUuid => 1,
        SignatureMatchKind.manufacturer => 2,
        SignatureMatchKind.macPrefix => 3,
      };

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

  SignatureMatch? _matchManufacturer(
    List<int> manufacturerIds,
    DetectionSignature signature,
  ) {
    if (signature.manufacturerIdHints.isEmpty || manufacturerIds.isEmpty) {
      return null;
    }
    final hints = signature.manufacturerIdHints.toSet();
    for (final id in manufacturerIds) {
      if (hints.contains(id)) {
        return SignatureMatch(
          signature: signature,
          kind: SignatureMatchKind.manufacturer,
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
    if (!shouldConsiderAddressPrefix(id) || signature.macPrefixHints.isEmpty) {
      return null;
    }

    final normalized = normalizeMac(id);
    if (normalized == null) return null;

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

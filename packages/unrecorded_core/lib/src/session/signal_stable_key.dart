import '../detection/signature_matcher.dart';
import '../models/detected_signal.dart';

/// Stable in-session key for merging observations.
///
/// Prefers scanner-provided [DetectedSignal.id]. Name-only fallback applies
/// only when the signal has a display name and no usable id.
String stableKeyFor(DetectedSignal signal) {
  final trimmedId = signal.id.trim();
  if (trimmedId.isNotEmpty) {
    return trimmedId.toLowerCase();
  }

  final name = signal.displayName?.trim().toLowerCase();
  if (name != null && name.isNotEmpty) {
    return 'name:$name';
  }

  return 'anon:${signal.hashCode}';
}

/// Normalised MAC from [id] when available (for matcher hints).
String? normalizedMacFromId(String id) => SignatureMatcher.normalizeMac(id);

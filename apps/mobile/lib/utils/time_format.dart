/// Shared relative-time formatting helpers for the mobile app.
library;

/// Returns a human-readable "Last checked: …" string relative to [t].
///
/// Returns `null` when [t] is null (convenience for nullable call sites).
String? relativeLastChecked(DateTime? t) {
  if (t == null) return null;
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Last checked: just now';
  if (diff.inMinutes < 60) return 'Last checked: ${diff.inMinutes} min ago';
  return 'Last checked: ${diff.inHours} h ago';
}

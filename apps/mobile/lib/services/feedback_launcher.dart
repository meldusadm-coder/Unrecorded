import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef FeedbackSubmitFn = Future<bool> Function(Uri uri);

/// Whether [canLaunchUrl] must succeed before calling [launchUrl].
///
/// Android 11+ only reports handlers declared in the manifest `<queries>`.
/// We declare [mailto] there; https links skip the pre-check so browsers still
/// open when the user taps "Open on GitHub" in the mailto fallback dialog.
bool feedbackUriRequiresCanLaunchCheck(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return scheme != 'http' && scheme != 'https';
}

Future<bool> launchFeedbackUri(Uri uri) async {
  if (feedbackUriRequiresCanLaunchCheck(uri)) {
    if (!await canLaunchUrl(uri)) return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

final feedbackSubmitFnProvider = Provider<FeedbackSubmitFn>(
  (ref) => launchFeedbackUri,
);

Future<bool> submitFeedbackUri(
  Uri uri, {
  required FeedbackSubmitFn submit,
}) =>
    submit(uri);

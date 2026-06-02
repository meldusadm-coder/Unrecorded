import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef FeedbackSubmitFn = Future<bool> Function(Uri uri);

final feedbackSubmitFnProvider = Provider<FeedbackSubmitFn>(
  (ref) => (uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);

Future<bool> submitFeedbackUri(
  Uri uri, {
  required FeedbackSubmitFn submit,
}) =>
    submit(uri);

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../features/scan/scan_state.dart';
import 'scan_runtime.dart';

/// Sanitised, opt-in diagnostic snapshot for feedback emails.
class FeedbackDiagnostics {
  const FeedbackDiagnostics({required this.entries});

  final Map<String, String> entries;
}

Future<FeedbackDiagnostics> collectFeedbackDiagnostics({
  required String appVersion,
  required String buildNumber,
  required ScannerMode? scannerMode,
  required ScanStatus? scanStatus,
  required bool protectionActive,
}) async {
  final platformLabel = await _platformLabel();

  final entries = <String, String>{
    'App version': appVersion,
    'Build': buildNumber,
    'Platform': platformLabel,
    'Scanner mode': scannerMode?.name ?? 'unknown',
  };

  if (protectionActive && scanStatus != null) {
    entries['Scan status'] = scanStatus.name;
  }

  return FeedbackDiagnostics(entries: entries);
}

Future<String> _platformLabel() async {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await deviceInfo.androidInfo;
    return 'Android ${info.version.release} / ${info.model}';
  }
  if (Platform.isIOS) {
    final info = await deviceInfo.iosInfo;
    return 'iOS ${info.systemVersion} / ${info.model}';
  }
  return 'Unknown platform';
}

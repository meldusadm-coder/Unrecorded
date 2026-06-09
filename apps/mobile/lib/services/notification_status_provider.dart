import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_prefs.dart';
import 'risk_notification_service.dart';

/// Whether OS-level notifications are currently enabled for this app.
final notificationsOsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(riskNotificationServiceProvider);
  await service.init();
  return service.notificationsOsEnabled();
});

/// User preference for possible-risk alert notifications.
final riskNotificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await NotificationPrefs.load();
  return prefs.riskNotificationsEnabled;
});

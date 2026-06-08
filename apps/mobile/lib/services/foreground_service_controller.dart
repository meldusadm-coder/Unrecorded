import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin interface over [FlutterForegroundTask] so Phase 1 can be
/// exercised from the UI and future phases can inject fakes in tests.
abstract class ForegroundServiceController {
  /// Set up IPC port and plugin options. Call once from main().
  void init();

  /// Register a callback for data sent from the task isolate.
  void addDataCallback(DataCallback callback);

  /// Remove a previously registered data callback.
  void removeDataCallback(DataCallback callback);

  /// Whether the foreground service is currently running.
  Future<bool> get isRunning;

  /// Start the foreground service with [notificationTitle] and [notificationText].
  ///
  /// The [callback] is the `@pragma('vm:entry-point')` top-level function
  /// that calls [FlutterForegroundTask.setTaskHandler].
  Future<ServiceRequestResult> start({
    required String notificationTitle,
    required String notificationText,
    required List<NotificationButton> notificationButtons,
    required Function callback,
  });

  /// Stop the foreground service.
  Future<ServiceRequestResult> stop();
}

// ---------------------------------------------------------------------------

/// Android notification channel for the foreground-service status notification.
const backgroundProtectionFgsChannelId = 'unrecorded_background_protection';

const _kFgsChannelId = backgroundProtectionFgsChannelId;
const _kFgsChannelName = 'Background protection';
const _kFgsChannelDescription =
    'Shows while Unrecorded background protection is active. '
    'Not proof of recording.';

class _RealForegroundServiceController implements ForegroundServiceController {
  @override
  void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _kFgsChannelId,
        channelName: _kFgsChannelName,
        channelDescription: _kFgsChannelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  @override
  void addDataCallback(DataCallback callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  @override
  void removeDataCallback(DataCallback callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  @override
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  @override
  Future<ServiceRequestResult> start({
    required String notificationTitle,
    required String notificationText,
    required List<NotificationButton> notificationButtons,
    required Function callback,
  }) {
    return FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.connectedDevice],
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      notificationButtons: notificationButtons,
      callback: callback,
    );
  }

  @override
  Future<ServiceRequestResult> stop() {
    return FlutterForegroundTask.stopService();
  }
}

final foregroundServiceControllerProvider =
    Provider<ForegroundServiceController>((ref) {
  final controller = _RealForegroundServiceController();
  if (!kIsWeb) controller.init();
  return controller;
});

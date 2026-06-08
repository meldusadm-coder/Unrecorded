import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:unrecorded_mobile/services/foreground_service_controller.dart';

class FakeForegroundServiceController implements ForegroundServiceController {
  bool running = false;
  ServiceRequestResult startResult = const ServiceRequestSuccess();
  final List<DataCallback> callbacks = [];
  String? lastNotificationTitle;
  Function? lastCallback;

  @override
  void init() {}

  @override
  void addDataCallback(DataCallback callback) {
    callbacks.add(callback);
  }

  @override
  void removeDataCallback(DataCallback callback) {
    callbacks.remove(callback);
  }

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<ServiceRequestResult> start({
    required String notificationTitle,
    required String notificationText,
    required List<NotificationButton> notificationButtons,
    required Function callback,
  }) async {
    lastNotificationTitle = notificationTitle;
    lastCallback = callback;
    if (startResult is ServiceRequestSuccess) {
      running = true;
    }
    return startResult;
  }

  @override
  Future<ServiceRequestResult> stop() async {
    running = false;
    return const ServiceRequestSuccess();
  }

  void emitTaskData(Object data) {
    for (final callback in callbacks.toList()) {
      callback(data);
    }
  }
}

import 'dart:io';

import 'package:unrecorded_core/unrecorded_core.dart';

import 'risk_notification_service.dart';
import 'scan_runtime.dart';

/// Result of preflight checks before starting background protection.
enum BackgroundProtectionPreflightFailure {
  notAndroid,
  notificationDenied,
  bluetoothUnsupported,
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothOff,
  serviceStartFailed,
}

class BackgroundProtectionPreflightResult {
  const BackgroundProtectionPreflightResult._(this.failure);

  const BackgroundProtectionPreflightResult.ok() : this._(null);

  const BackgroundProtectionPreflightResult.fail(this.failure);

  final BackgroundProtectionPreflightFailure? failure;

  bool get isOk => failure == null;
}

/// Main-isolate preflight before starting the foreground service.
///
/// Requests notification permission (required) and BLE permissions, then
/// checks Bluetooth readiness. Never called from the task isolate.
class BackgroundProtectionPreflight {
  const BackgroundProtectionPreflight({
    required ScanRuntime runtime,
    required RiskNotificationService notifications,
  })  : _runtime = runtime,
        _notifications = notifications;

  final ScanRuntime _runtime;
  final RiskNotificationService _notifications;

  Future<BackgroundProtectionPreflightResult> check({
    bool requestPermissions = true,
  }) async {
    if (!Platform.isAndroid) {
      return const BackgroundProtectionPreflightResult.fail(
        BackgroundProtectionPreflightFailure.notAndroid,
      );
    }

    if (requestPermissions) {
      final notificationGranted =
          await _notifications.requestPermissionIfNeeded();
      if (!notificationGranted) {
        return const BackgroundProtectionPreflightResult.fail(
          BackgroundProtectionPreflightFailure.notificationDenied,
        );
      }
    } else if (!await _notifications.notificationsOsEnabled()) {
      return const BackgroundProtectionPreflightResult.fail(
        BackgroundProtectionPreflightFailure.notificationDenied,
      );
    }

    final bleResult = await _runtime.ensureAndroidReady();
    if (!bleResult.isOk) {
      return BackgroundProtectionPreflightResult.fail(
        _mapBleFailure(bleResult.failure!),
      );
    }

    return const BackgroundProtectionPreflightResult.ok();
  }

  BackgroundProtectionPreflightFailure _mapBleFailure(
    ScanPreflightFailure failure,
  ) {
    return switch (failure) {
      ScanPreflightFailure.permissionDenied =>
        BackgroundProtectionPreflightFailure.permissionDenied,
      ScanPreflightFailure.permissionPermanentlyDenied =>
        BackgroundProtectionPreflightFailure.permissionPermanentlyDenied,
      ScanPreflightFailure.bluetoothOff =>
        BackgroundProtectionPreflightFailure.bluetoothOff,
      ScanPreflightFailure.bluetoothUnsupported =>
        BackgroundProtectionPreflightFailure.bluetoothUnsupported,
    };
  }

  String messageFor(BackgroundProtectionPreflightFailure failure) {
    return switch (failure) {
      BackgroundProtectionPreflightFailure.notAndroid =>
        'Background protection is only available on Android.',
      BackgroundProtectionPreflightFailure.notificationDenied =>
        AppCopy.backgroundProtectionNotificationRequired,
      BackgroundProtectionPreflightFailure.bluetoothUnsupported =>
        AppCopy.bluetoothUnsupportedMessage,
      BackgroundProtectionPreflightFailure.permissionDenied =>
        AppCopy.permissionHelper,
      BackgroundProtectionPreflightFailure.permissionPermanentlyDenied =>
        AppCopy.permissionPermanentlyDeniedHelper,
      BackgroundProtectionPreflightFailure.bluetoothOff =>
        AppCopy.bluetoothOffMessage,
      BackgroundProtectionPreflightFailure.serviceStartFailed =>
        AppCopy.backgroundProtectionServiceStartFailed,
    };
  }
}

import 'dart:io';

import 'package:unrecorded_core/unrecorded_core.dart';

import 'risk_notification_service.dart';
import 'scan_preflight_mapping.dart';
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
        backgroundPreflightFailureFor(bleResult.failure!),
      );
    }

    return const BackgroundProtectionPreflightResult.ok();
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
        preflightMessageFor(ScanPreflightFailure.permissionDenied),
      BackgroundProtectionPreflightFailure.permissionPermanentlyDenied =>
        preflightMessageFor(ScanPreflightFailure.permissionPermanentlyDenied),
      BackgroundProtectionPreflightFailure.bluetoothOff =>
        preflightMessageFor(ScanPreflightFailure.bluetoothOff),
      BackgroundProtectionPreflightFailure.serviceStartFailed =>
        AppCopy.backgroundProtectionServiceStartFailed,
    };
  }
}

import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'scan_runtime.dart';

/// A [ScanRuntime] that only checks existing state; it never triggers
/// runtime permission prompts. Safe for use in the task isolate where
/// prompting is not possible.
class BackgroundScanRuntime extends ScanRuntime {
  const BackgroundScanRuntime();

  @override
  bool get isAndroid => Platform.isAndroid;

  /// Checks BLE permission state and adapter readiness without requesting anything.
  @override
  Future<ScanPreflightResult> ensureAndroidReady() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.bluetoothUnsupported,
      );
    }

    if (!await _permissionsAlreadyGranted()) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.permissionDenied,
      );
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      return const ScanPreflightResult.fail(ScanPreflightFailure.bluetoothOff);
    }

    return const ScanPreflightResult.ok();
  }

  Future<bool> _permissionsAlreadyGranted() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    if (scan.isGranted && connect.isGranted) return true;
    // Pre-Android 12 fallback.
    final loc = await Permission.locationWhenInUse.status;
    return loc.isGranted;
  }
}

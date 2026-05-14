import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum ScannerMode { auto, demo }

enum ScanPreflightFailure {
  permissionDenied,
  bluetoothUnsupported,
  bluetoothOff,
}

class ScanPreflightResult {
  final ScanPreflightFailure? failure;

  const ScanPreflightResult._(this.failure);

  const ScanPreflightResult.ok() : this._(null);

  const ScanPreflightResult.fail(ScanPreflightFailure failure)
      : this._(failure);

  bool get isOk => failure == null;
}

class ScanRuntime {
  const ScanRuntime();

  bool get isAndroid => Platform.isAndroid;

  Future<ScanPreflightResult> ensureAndroidReady() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.bluetoothUnsupported,
      );
    }

    final permissionGranted = await _requestPermissions();
    if (!permissionGranted) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.permissionDenied,
      );
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.bluetoothOff,
      );
    }

    return const ScanPreflightResult.ok();
  }

  Future<bool> _requestPermissions() async {
    final sdkInt = await FlutterBluePlus.androidSdk;
    if (sdkInt >= 31) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      return statuses.values.every((s) => s.isGranted);
    }

    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }
}

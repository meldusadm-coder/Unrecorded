// dart format off
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum ScannerMode { auto, demo }

enum ScanPreflightFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothUnsupported,
  bluetoothOff
}

class ScanPreflightResult {
  const ScanPreflightResult._(this.failure);

  const ScanPreflightResult.ok() : this._(null);

  const ScanPreflightResult.fail(this.failure);

  final ScanPreflightFailure? failure;

  bool get isOk => failure == null;
}

class ScanRuntime {
  const ScanRuntime();

  bool get isAndroid => Platform.isAndroid;

  /// True on Android emulators / iOS simulators (debug UAT default).
  Future<bool> isEmulator() async {
    if (kIsWeb) return false;
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return !android.isPhysicalDevice;
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return !ios.isPhysicalDevice;
    }
    return false;
  }

  Future<ScanPreflightResult> ensureAndroidReady() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      return const ScanPreflightResult.fail(
        ScanPreflightFailure.bluetoothUnsupported,
      );
    }

    final permissionGranted = await _requestPermissions();
    if (!permissionGranted) {
      final permanentlyDenied = await isPermissionPermanentlyDenied();
      return ScanPreflightResult.fail(
        permanentlyDenied
            ? ScanPreflightFailure.permissionPermanentlyDenied
            : ScanPreflightFailure.permissionDenied,
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
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      final scanStatus = statuses[Permission.bluetoothScan];
      final connectStatus = statuses[Permission.bluetoothConnect];
      if ((scanStatus?.isPermanentlyDenied ?? false) ||
          (connectStatus?.isPermanentlyDenied ?? false)) {
        return false;
      }
      return (scanStatus?.isGranted ?? false) && (connectStatus?.isGranted ?? false);
    }

    final statuses = await [
      Permission.locationWhenInUse,
    ].request();

    return statuses[Permission.locationWhenInUse]?.isGranted ?? false;
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      final scan = await Permission.bluetoothScan.status;
      final connect = await Permission.bluetoothConnect.status;
      return scan.isPermanentlyDenied || connect.isPermanentlyDenied;
    }
    final location = await Permission.locationWhenInUse.status;
    return location.isPermanentlyDenied;
  }
}

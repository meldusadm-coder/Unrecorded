import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'radio_scan_result.dart';
import 'radio_scanner.dart';
import 'radio_scanner_exception.dart';

/// BLE scanner using [flutter_blue_plus].
///
/// Important caveats:
/// - Android and iOS scanning capabilities differ significantly.
/// - iOS background scanning is limited by CoreBluetooth restrictions.
/// - Device names may be hidden or randomised by the OS or device firmware.
/// - BLE detection is a risk signal, not proof of recording.
///
/// TODO: Add deeper native Android (Kotlin) scanner for background scanning.
/// TODO: Add deeper native iOS (Swift/CoreBluetooth) scanner for background use.
class BleRadioScanner implements RadioScanner {
  StreamController<List<RadioScanResult>>? _controller;
  StreamSubscription<List<ScanResult>>? _subscription;
  bool _scanning = false;

  @override
  bool get isScanning => _scanning;

  @override
  Stream<List<RadioScanResult>> scan() {
    _controller = StreamController<List<RadioScanResult>>(
      onCancel: () => stop(),
    );

    _startBle();
    return _controller!.stream;
  }

  Future<void> _startBle() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        throw const RadioScannerException(
          'Bluetooth is not supported on this device.',
        );
      }

      // Wait for adapter to be ready.
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw const RadioScannerException(
              'Bluetooth adapter did not turn on in time.',
            ),
          );

      _scanning = true;

      // No timeout — scan runs until [stop] is called. The scan controller
      // restarts the stream if the platform ends a session early.
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
      );

      _subscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          if (_controller == null || _controller!.isClosed) return;
          _controller!.add(results.map(_mapResult).toList());
        },
        onError: (Object e) {
          _controller?.addError(
            RadioScannerException('BLE scan error', cause: e),
          );
        },
      );
    } on RadioScannerException {
      rethrow;
    } catch (e) {
      _controller?.addError(
        RadioScannerException('Failed to start BLE scan', cause: e),
      );
    }
  }

  @override
  Future<void> stop() async {
    _scanning = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Best-effort stop.
    }
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }

  static RadioScanResult _mapResult(ScanResult r) {
    return RadioScanResult(
      id: r.device.remoteId.str,
      name: r.device.platformName.isNotEmpty ? r.device.platformName : null,
      rssi: r.rssi,
      serviceUuids: r.advertisementData.serviceUuids.map((e) => e.str).toList(),
      isConnectable: r.advertisementData.connectable,
      observedAt: DateTime.now(),
    );
  }
}

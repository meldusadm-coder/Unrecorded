import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_scan_result_mapper.dart';
import 'radio_scan_result.dart';
import 'radio_scanner.dart';
import 'radio_scanner_exception.dart';
import 'radio_start_result.dart';
import 'radio_stop_result.dart';

/// BLE scanner using [flutter_blue_plus].
///
/// Important caveats:
/// - Android and iOS scanning capabilities differ significantly.
/// - iOS background scanning is limited by CoreBluetooth restrictions.
/// - Device names may be hidden or randomised by the OS or device firmware.
/// - BLE detection is a risk signal, not proof of recording.
///
/// Start/stop are serialised. [isScanning] is true only after
/// [FlutterBluePlus.startScan] succeeds. A thrown [FlutterBluePlus.stopScan]
/// always yields [RadioStopFailed] with `mayStillBeScanning: true` because
/// flutter_blue_plus sets `isScanningNow` false before the native
/// await, so Dart state cannot prove native stop after that exception.
///
/// TODO: Add deeper native Android (Kotlin) scanner for background scanning.
/// TODO: Add deeper native iOS (Swift/CoreBluetooth) scanner for background use.
class BleRadioScanner implements RadioScanner {
  StreamController<List<RadioScanResult>>? _controller;
  StreamSubscription<List<ScanResult>>? _subscription;
  bool _scanning = false;
  bool _platformStarted = false;
  bool _cancelRequested = false;

  /// Serialises start/stop so only one generation runs at a time.
  Future<void> _chain = Future<void>.value();

  @override
  bool get isScanning => _scanning;

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _chain;
    final gate = Completer<void>();
    _chain = gate.future;
    try {
      await previous;
      return await action();
    } finally {
      gate.complete();
    }
  }

  @override
  Future<RadioStartResult> start() {
    return _serialized(() async {
      if (_scanning || _platformStarted) {
        return RadioStartFailed(
          const RadioScannerException('BLE scan already active.'),
          mayStillBeScanning: true,
        );
      }

      _cancelRequested = false;
      final controller = StreamController<List<RadioScanResult>>.broadcast();
      _controller = controller;

      try {
        final isSupported = await FlutterBluePlus.isSupported;
        if (!isSupported) {
          await _closeControllerOnly();
          return RadioStartFailed(
            const RadioScannerException(
              'Bluetooth is not supported on this device.',
            ),
            mayStillBeScanning: false,
          );
        }

        if (_cancelRequested) {
          await _closeControllerOnly();
          return RadioStartCancelledAndStopped();
        }

        // Wait for adapter to be ready.
        try {
          await FlutterBluePlus.adapterState
              .firstWhere((s) => s == BluetoothAdapterState.on)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw const RadioScannerException(
                  'Bluetooth adapter did not turn on in time.',
                ),
              );
        } on RadioScannerException catch (e) {
          await _closeControllerOnly();
          return RadioStartFailed(e, mayStillBeScanning: false);
        }

        if (_cancelRequested) {
          await _closeControllerOnly();
          return RadioStartCancelledAndStopped();
        }

        // No timeout — scan runs until [stop] is called. The scan controller
        // restarts the stream if the platform ends a session early.
        // Android 12+ uses BLUETOOTH_SCAN with neverForLocation — do not request
        // fine location at scan time (manifest excludes it on API 31+).
        await FlutterBluePlus.startScan(
          androidUsesFineLocation: false,
          androidCheckLocationServices: false,
        );
        _platformStarted = true;

        if (_cancelRequested) {
          // Late success: stop path (queued behind us) will call stopScan.
          // Leave _platformStarted true so stop cleans up; do not mark scanning.
          return RadioStartCancelledAndStopped();
        }

        _scanning = true;
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

        return RadioStarted(controller.stream);
      } on RadioScannerException catch (e) {
        await _closeControllerOnly();
        return RadioStartFailed(e, mayStillBeScanning: false);
      } catch (e) {
        await _closeControllerOnly();
        return RadioStartFailed(
          RadioScannerException('Failed to start BLE scan', cause: e),
          mayStillBeScanning: false,
        );
      }
    });
  }

  @override
  Future<RadioStopResult> stop() {
    _cancelRequested = true;
    return _serialized(() async {
      if (!_scanning && !_platformStarted) {
        await _closeControllerOnly();
        return const RadioAlreadyStopped();
      }

      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // flutter_blue_plus sets isScanningNow false before native
        // await, so a thrown stopScan can never prove native inactivity.
        return RadioStopFailed(
          RadioScannerException('Failed to stop BLE scan', cause: e),
          mayStillBeScanning: true,
        );
      }

      await _subscription?.cancel();
      _subscription = null;
      await _closeControllerOnly();
      _scanning = false;
      _platformStarted = false;
      _cancelRequested = false;
      return const RadioStopped();
    });
  }

  Future<void> _closeControllerOnly() async {
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  static RadioScanResult _mapResult(ScanResult r) {
    return mapBleAdvertisement(
      BleAdvertisement(
        id: r.device.remoteId.str,
        advertisedName: r.advertisementData.advName,
        platformName: r.device.platformName,
        rssi: r.rssi,
        serviceUuids:
            r.advertisementData.serviceUuids.map((e) => e.str).toList(),
        manufacturerIds: r.advertisementData.manufacturerData.keys.toList(),
        isConnectable: r.advertisementData.connectable,
      ),
      observedAt: DateTime.now(),
    );
  }
}

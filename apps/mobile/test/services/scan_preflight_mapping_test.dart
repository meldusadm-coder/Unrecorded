import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/background_protection_preflight.dart';
import 'package:unrecorded_mobile/services/scan_preflight_mapping.dart';
import 'package:unrecorded_mobile/services/scan_runtime.dart';

void main() {
  test('scanStatusForPreflightFailure maps all BLE failures', () {
    expect(
      scanStatusForPreflightFailure(ScanPreflightFailure.permissionDenied),
      ScanStatus.permissionDenied,
    );
    expect(
      scanStatusForPreflightFailure(
        ScanPreflightFailure.permissionPermanentlyDenied,
      ),
      ScanStatus.permissionPermanentlyDenied,
    );
    expect(
      scanStatusForPreflightFailure(ScanPreflightFailure.bluetoothOff),
      ScanStatus.bluetoothOff,
    );
    expect(
      scanStatusForPreflightFailure(ScanPreflightFailure.bluetoothUnsupported),
      ScanStatus.bluetoothUnsupported,
    );
  });

  test('backgroundPreflightFailureFor maps BLE failures', () {
    expect(
      backgroundPreflightFailureFor(ScanPreflightFailure.permissionDenied),
      BackgroundProtectionPreflightFailure.permissionDenied,
    );
    expect(
      backgroundPreflightFailureFor(ScanPreflightFailure.bluetoothOff),
      BackgroundProtectionPreflightFailure.bluetoothOff,
    );
  });

  test('preflightMessageFor returns non-empty copy', () {
    for (final failure in ScanPreflightFailure.values) {
      expect(preflightMessageFor(failure), isNotEmpty);
    }
  });
}

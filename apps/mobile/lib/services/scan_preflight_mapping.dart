import 'package:unrecorded_core/unrecorded_core.dart';

import '../features/scan/scan_state.dart';
import 'background_protection_preflight.dart';
import 'scan_runtime.dart';

/// Maps BLE readiness failures to UI scan status (main and task isolates).
ScanStatus scanStatusForPreflightFailure(ScanPreflightFailure failure) {
  return switch (failure) {
    ScanPreflightFailure.permissionDenied => ScanStatus.permissionDenied,
    ScanPreflightFailure.permissionPermanentlyDenied =>
      ScanStatus.permissionPermanentlyDenied,
    ScanPreflightFailure.bluetoothOff => ScanStatus.bluetoothOff,
    ScanPreflightFailure.bluetoothUnsupported =>
      ScanStatus.bluetoothUnsupported,
  };
}

/// User-facing message for a BLE readiness failure.
String preflightMessageFor(ScanPreflightFailure failure) {
  return switch (failure) {
    ScanPreflightFailure.permissionDenied => AppCopy.permissionHelper,
    ScanPreflightFailure.permissionPermanentlyDenied =>
      AppCopy.permissionPermanentlyDeniedHelper,
    ScanPreflightFailure.bluetoothUnsupported =>
      AppCopy.bluetoothUnsupportedMessage,
    ScanPreflightFailure.bluetoothOff => AppCopy.bluetoothOffMessage,
  };
}

/// Maps BLE readiness failures to background-protection preflight failures.
BackgroundProtectionPreflightFailure backgroundPreflightFailureFor(
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

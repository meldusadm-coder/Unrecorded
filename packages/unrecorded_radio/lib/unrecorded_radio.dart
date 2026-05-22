/// Radio scanner abstraction for Unrecorded.
///
/// Provides a [RadioScanner] interface with a [FakeRadioScanner] for
/// demo/testing and a [BleRadioScanner] for real BLE hardware access.
library;

export 'src/radio_scanner.dart';
export 'src/radio_scan_result.dart';
export 'src/fake_demo_scenario.dart';
export 'src/fake_radio_scanner.dart';
export 'src/ble_radio_scanner.dart';
export 'src/radio_scanner_exception.dart';

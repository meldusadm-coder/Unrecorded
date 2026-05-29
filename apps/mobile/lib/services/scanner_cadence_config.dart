/// Battery-aware foreground scan window timing.
class ScannerCadenceConfig {
  const ScannerCadenceConfig({
    this.scanWindow = const Duration(seconds: 10),
    this.restInterval = const Duration(seconds: 15),
  });

  final Duration scanWindow;
  final Duration restInterval;
}

const defaultScannerCadence = ScannerCadenceConfig();

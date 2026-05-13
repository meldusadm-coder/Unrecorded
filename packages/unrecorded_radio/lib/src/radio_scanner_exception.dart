/// Exception thrown when a radio scanner encounters an unrecoverable error.
class RadioScannerException implements Exception {
  final String message;
  final Object? cause;

  const RadioScannerException(this.message, {this.cause});

  @override
  String toString() => 'RadioScannerException: $message';
}

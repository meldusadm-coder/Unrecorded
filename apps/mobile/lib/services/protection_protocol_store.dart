import 'protection_protocol_models.dart';

/// Dart boundary for the Android protection protocol repository.
///
/// Android uses MethodChannel `app.unrecorded/protection_protocol`.
/// Non-Android uses the single-engine SharedPreferences adapter.
abstract class ProtectionProtocolStore {
  /// Best-effort revision pings. Payload alone is not trusted — reread state.
  Stream<ProtocolChangeNotification> get changes;

  Future<ProtectionProtocolState> getState();

  Future<ProtocolCommitResult> ensureReady();

  Future<ProtocolCommitResult> commitExplicitStop();

  Future<ProtocolCommitResult> setBackgroundModePreferred({
    required int expectedRevision,
    required bool preferred,
  });

  Future<ProtocolCommitResult> beginForegroundIntent({
    required int expectedRevision,
  });

  Future<ProtocolCommitResult> allocateBackgroundSession({
    required int expectedRevision,
    required String attemptId,
    required String processId,
  });

  Future<ProtocolCommitResult> cancelBackgroundAttempt({
    required String attemptId,
  });

  Future<ProtocolCommitResult> switchToForegroundIntent({
    required int expectedRevision,
  });

  Future<ProtocolCommitResult> claimTaskIncarnation({
    required int expectedRevision,
    required String sessionId,
    required String incarnationId,
  });

  Future<ProtocolCommitResult> markTaskScannerReady({
    required int expectedRevision,
    required String sessionId,
    required int epoch,
    required String incarnationId,
    required String leaseId,
  });

  Future<ProtocolCommitResult> markNativeStartResolved({
    required int expectedRevision,
    required String attemptId,
  });

  Future<ProtocolCommitResult> finaliseSession({
    required int expectedRevision,
    required String sessionId,
  });

  Future<ProtocolCommitResult> reapDeadProcessStartLatch({
    required int expectedRevision,
    required String processId,
  });

  Future<ScannerLeaseAcquireResult> acquireForegroundLease({
    String? rollbackForAttemptId,
  });

  Future<ScannerLeaseAcquireResult> acquireTaskLease({
    required String sessionId,
    required int epoch,
    String? incarnationId,
  });

  Future<bool> markLeaseActive({required String leaseId});

  Future<bool> releaseLease({required String leaseId});

  /// Releases the lease owned by this engine incarnation, if any.
  Future<bool> releaseLeaseForEngine();

  Future<void> dispose();
}

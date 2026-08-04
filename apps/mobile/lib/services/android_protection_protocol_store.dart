import 'dart:async';

import 'package:flutter/services.dart';

import 'protection_protocol_models.dart';
import 'protection_protocol_store.dart';

/// MethodChannel client for `app.unrecorded/protection_protocol`.
class AndroidProtectionProtocolStore implements ProtectionProtocolStore {
  AndroidProtectionProtocolStore({
    MethodChannel? channel,
  }) : _channel = channel ??
            const MethodChannel(AndroidProtectionProtocolStore.channelName) {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const channelName = 'app.unrecorded/protection_protocol';

  final MethodChannel _channel;
  final StreamController<ProtocolChangeNotification> _changes =
      StreamController<ProtocolChangeNotification>.broadcast();

  var _disposed = false;

  @override
  Stream<ProtocolChangeNotification> get changes => _changes.stream;

  @override
  Future<ProtectionProtocolState> getState() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('getState');
    if (raw == null) {
      throw StateError('getState returned null');
    }
    return ProtectionProtocolState.fromWireMap(raw);
  }

  @override
  Future<ProtocolCommitResult> ensureReady() => _invokeCommit('ensureReady');

  @override
  Future<ProtocolCommitResult> commitExplicitStop() =>
      _invokeCommit('commitExplicitStop');

  @override
  Future<ProtocolCommitResult> setBackgroundModePreferred({
    required int expectedRevision,
    required bool preferred,
  }) {
    return _invokeCommit(
      'setBackgroundModePreferred',
      arguments: {
        'expectedRevision': expectedRevision,
        'preferred': preferred,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> beginForegroundIntent({
    required int expectedRevision,
  }) {
    return _invokeCommit(
      'beginForegroundIntent',
      arguments: {'expectedRevision': expectedRevision},
    );
  }

  @override
  Future<ProtocolCommitResult> allocateBackgroundSession({
    required int expectedRevision,
    required String attemptId,
    required String processId,
  }) {
    return _invokeCommit(
      'allocateBackgroundSession',
      arguments: {
        'expectedRevision': expectedRevision,
        'attemptId': attemptId,
        'processId': processId,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> cancelBackgroundAttempt({
    required String attemptId,
  }) {
    return _invokeCommit(
      'cancelBackgroundAttempt',
      arguments: {'attemptId': attemptId},
    );
  }

  @override
  Future<ProtocolCommitResult> switchToForegroundIntent({
    required int expectedRevision,
  }) {
    return _invokeCommit(
      'switchToForegroundIntent',
      arguments: {'expectedRevision': expectedRevision},
    );
  }

  @override
  Future<ProtocolCommitResult> claimTaskIncarnation({
    required int expectedRevision,
    required String sessionId,
    required String incarnationId,
  }) {
    return _invokeCommit(
      'claimTaskIncarnation',
      arguments: {
        'expectedRevision': expectedRevision,
        'sessionId': sessionId,
        'incarnationId': incarnationId,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> markTaskScannerReady({
    required int expectedRevision,
    required String sessionId,
    required int epoch,
    required String incarnationId,
    required String leaseId,
  }) {
    return _invokeCommit(
      'markTaskScannerReady',
      arguments: {
        'expectedRevision': expectedRevision,
        'sessionId': sessionId,
        'epoch': epoch,
        'incarnationId': incarnationId,
        'leaseId': leaseId,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> markNativeStartResolved({
    required int expectedRevision,
    required String attemptId,
  }) {
    return _invokeCommit(
      'markNativeStartResolved',
      arguments: {
        'expectedRevision': expectedRevision,
        'attemptId': attemptId,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> finaliseSession({
    required int expectedRevision,
    required String sessionId,
  }) {
    return _invokeCommit(
      'finaliseSession',
      arguments: {
        'expectedRevision': expectedRevision,
        'sessionId': sessionId,
      },
    );
  }

  @override
  Future<ProtocolCommitResult> reapDeadProcessStartLatch({
    required int expectedRevision,
    required String processId,
  }) {
    return _invokeCommit(
      'reapDeadProcessStartLatch',
      arguments: {
        'expectedRevision': expectedRevision,
        'processId': processId,
      },
    );
  }

  @override
  Future<ScannerLeaseAcquireResult> acquireForegroundLease({
    String? rollbackForAttemptId,
  }) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'acquireForegroundLease',
      {
        if (rollbackForAttemptId != null)
          'rollbackForAttemptId': rollbackForAttemptId,
      },
    );
    if (raw == null) {
      throw StateError('acquireForegroundLease returned null');
    }
    return ScannerLeaseAcquireResult.fromWireMap(raw);
  }

  @override
  Future<ScannerLeaseAcquireResult> acquireTaskLease({
    required String sessionId,
    required int epoch,
    String? incarnationId,
  }) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'acquireTaskLease',
      {
        'sessionId': sessionId,
        'epoch': epoch,
        if (incarnationId != null) 'incarnationId': incarnationId,
      },
    );
    if (raw == null) {
      throw StateError('acquireTaskLease returned null');
    }
    return ScannerLeaseAcquireResult.fromWireMap(raw);
  }

  @override
  Future<bool> markLeaseActive({required String leaseId}) async {
    final raw = await _channel.invokeMethod<bool>(
      'markLeaseActive',
      {'leaseId': leaseId},
    );
    return raw ?? false;
  }

  @override
  Future<bool> releaseLease({required String leaseId}) async {
    final raw = await _channel.invokeMethod<bool>(
      'releaseLease',
      {'leaseId': leaseId},
    );
    return raw ?? false;
  }

  @override
  Future<bool> releaseLeaseForEngine() async {
    final raw = await _channel.invokeMethod<bool>('releaseLeaseForEngine');
    return raw ?? false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await _changes.close();
  }

  Future<ProtocolCommitResult> _invokeCommit(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      method,
      arguments,
    );
    if (raw == null) {
      throw StateError('$method returned null');
    }
    return ProtocolCommitResult.fromWireMap(raw);
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (_disposed) return null;
    if (call.method == 'onProtocolChanged') {
      final args = call.arguments;
      if (args is Map) {
        final map = Map<String, Object?>.from(args);
        final revision = map['revision'];
        final incarnation = map['engineIncarnationId'];
        if (revision is num && incarnation is String) {
          _changes.add(
            ProtocolChangeNotification(
              revision: revision.toInt(),
              engineIncarnationId: incarnation,
            ),
          );
        }
      }
    }
    return null;
  }
}

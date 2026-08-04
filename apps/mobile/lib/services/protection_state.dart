import 'protection_protocol_models.dart';
import 'scan_preflight_failure.dart';

/// Who currently owns the radio scanner (confirmed).
enum ScannerOwner {
  none,
  foreground,
  background,
}

/// Foreground scanner mechanics phase.
enum ForegroundMechanics {
  inactive,
  starting,
  active,
  stopping,
  uncertain,
}

/// Background foreground-service mechanics phase.
enum BackgroundServiceMechanics {
  stopped,
  starting,
  runningUnready,
  ready,
  stopping,
  unresponsive,
}

/// In-flight orchestrator transition.
enum ProtectionTransitionPhase {
  idle,
  enablingForeground,
  enablingBackground,
  switchingToBackground,
  switchingToForeground,
  reconciling,
  rollingBack,
  finalisingStop,
  disposing,
}

/// Stabilised issue surfaced after a failed or incomplete command.
enum BackgroundProtectionIssue {
  protocolUnavailable,
  protocolPersistenceFailed,
  foregroundStartFailed,
  foregroundPauseFailed,
  foregroundStopFailed,
  mainPreflightFailed,
  taskBlocked,
  serviceStartFailed,
  serviceStopFailed,
  readinessTimeout,
  serviceUnresponsive,
  staleStartCleanupPending,
  androidStoppedBackgroundProtection,
  inconsistentLegacyCleanup,
  backgroundSwitchFailed,
  backgroundNotSupported,
  leaseAcquireFailed,
  unknown,
}

/// Opaque native lease observation used for ownership / Stop finalisation.
class ScannerLeaseView {
  const ScannerLeaseView({
    required this.lease,
    required this.observedAt,
  });

  final ScannerLease? lease;
  final DateTime observedAt;
}

/// Mutable gate: only the orchestrator acquires/releases; ScanController reads.
class BackgroundOwnershipClaim {
  bool _held = false;

  bool get isHeld => _held;

  void acquire() => _held = true;

  void release() => _held = false;
}

/// In-memory orchestrator state published to Riverpod.
class ProtectionOrchestratorState {
  const ProtectionOrchestratorState({
    this.lastConfirmedTuple,
    this.confirmedOwner = ScannerOwner.none,
    this.foregroundMechanics = ForegroundMechanics.inactive,
    this.backgroundMechanics = BackgroundServiceMechanics.stopped,
    this.foregroundMayBeActive = false,
    this.backgroundMayBeActive = false,
    this.transition = ProtectionTransitionPhase.idle,
    this.issue,
    this.activeOperationId,
    this.retainedCleanup = false,
    this.disposed = false,
    this.lastLeaseView,
    this.lastAcceptedTaskSequence,
    this.engineIncarnationId,
    this.processInstanceId,
  });

  final ProtectionProtocolTuple? lastConfirmedTuple;
  final ScannerOwner confirmedOwner;
  final ForegroundMechanics foregroundMechanics;
  final BackgroundServiceMechanics backgroundMechanics;
  final bool foregroundMayBeActive;
  final bool backgroundMayBeActive;
  final ProtectionTransitionPhase transition;
  final BackgroundProtectionIssue? issue;
  final String? activeOperationId;
  final bool retainedCleanup;
  final bool disposed;
  final ScannerLeaseView? lastLeaseView;
  final int? lastAcceptedTaskSequence;
  final String? engineIncarnationId;
  final String? processInstanceId;

  bool get isBusy =>
      activeOperationId != null ||
      retainedCleanup ||
      transition != ProtectionTransitionPhase.idle;

  bool get isStableOff =>
      !disposed &&
      !isBusy &&
      confirmedOwner == ScannerOwner.none &&
      !foregroundMayBeActive &&
      !backgroundMayBeActive &&
      foregroundMechanics == ForegroundMechanics.inactive &&
      backgroundMechanics == BackgroundServiceMechanics.stopped &&
      (lastConfirmedTuple == null ||
          (!lastConfirmedTuple!.protectionEnabled &&
              !lastConfirmedTuple!.backgroundRuntimeEnabled));

  ProtectionOrchestratorState copyWith({
    Object? lastConfirmedTuple = _unset,
    ScannerOwner? confirmedOwner,
    ForegroundMechanics? foregroundMechanics,
    BackgroundServiceMechanics? backgroundMechanics,
    bool? foregroundMayBeActive,
    bool? backgroundMayBeActive,
    ProtectionTransitionPhase? transition,
    Object? issue = _unset,
    Object? activeOperationId = _unset,
    bool? retainedCleanup,
    bool? disposed,
    Object? lastLeaseView = _unset,
    Object? lastAcceptedTaskSequence = _unset,
    Object? engineIncarnationId = _unset,
    Object? processInstanceId = _unset,
  }) {
    return ProtectionOrchestratorState(
      lastConfirmedTuple: identical(lastConfirmedTuple, _unset)
          ? this.lastConfirmedTuple
          : lastConfirmedTuple as ProtectionProtocolTuple?,
      confirmedOwner: confirmedOwner ?? this.confirmedOwner,
      foregroundMechanics: foregroundMechanics ?? this.foregroundMechanics,
      backgroundMechanics: backgroundMechanics ?? this.backgroundMechanics,
      foregroundMayBeActive:
          foregroundMayBeActive ?? this.foregroundMayBeActive,
      backgroundMayBeActive:
          backgroundMayBeActive ?? this.backgroundMayBeActive,
      transition: transition ?? this.transition,
      issue: identical(issue, _unset)
          ? this.issue
          : issue as BackgroundProtectionIssue?,
      activeOperationId: identical(activeOperationId, _unset)
          ? this.activeOperationId
          : activeOperationId as String?,
      retainedCleanup: retainedCleanup ?? this.retainedCleanup,
      disposed: disposed ?? this.disposed,
      lastLeaseView: identical(lastLeaseView, _unset)
          ? this.lastLeaseView
          : lastLeaseView as ScannerLeaseView?,
      lastAcceptedTaskSequence: identical(lastAcceptedTaskSequence, _unset)
          ? this.lastAcceptedTaskSequence
          : lastAcceptedTaskSequence as int?,
      engineIncarnationId: identical(engineIncarnationId, _unset)
          ? this.engineIncarnationId
          : engineIncarnationId as String?,
      processInstanceId: identical(processInstanceId, _unset)
          ? this.processInstanceId
          : processInstanceId as String?,
    );
  }
}

const Object _unset = Object();

/// Public command outcomes. Each admitted command Completer completes once.
sealed class ProtectionCommandOutcome {
  const ProtectionCommandOutcome();
}

final class ProtectionCompleted extends ProtectionCommandOutcome {
  const ProtectionCompleted();
}

final class ProtectionNoOp extends ProtectionCommandOutcome {
  const ProtectionNoOp();
}

final class ProtectionBusy extends ProtectionCommandOutcome {
  const ProtectionBusy();
}

final class ProtectionSuperseded extends ProtectionCommandOutcome {
  const ProtectionSuperseded();
}

final class ProtectionFailed extends ProtectionCommandOutcome {
  const ProtectionFailed(this.issue);
  final BackgroundProtectionIssue issue;
}

final class ProtectionDisposed extends ProtectionCommandOutcome {
  const ProtectionDisposed();
}

/// Typed foreground start result (mechanics only).
sealed class ForegroundStartResult {
  const ForegroundStartResult();
}

final class ForegroundStarted extends ForegroundStartResult {
  const ForegroundStarted();
}

final class ForegroundAlreadyActive extends ForegroundStartResult {
  const ForegroundAlreadyActive();
}

final class ForegroundSuppressedByBackground extends ForegroundStartResult {
  const ForegroundSuppressedByBackground();
}

final class ForegroundStartPreflightFailed extends ForegroundStartResult {
  const ForegroundStartPreflightFailed(this.failure);
  final ScanPreflightFailure failure;
}

final class ForegroundStartMechanicalFailed extends ForegroundStartResult {
  const ForegroundStartMechanicalFailed({required this.mayStillBeScanning});
  final bool mayStillBeScanning;
}

/// Typed foreground pause result (mechanics only).
sealed class ForegroundPauseResult {
  const ForegroundPauseResult();
}

final class ForegroundPaused extends ForegroundPauseResult {
  const ForegroundPaused();
}

final class ForegroundAlreadyInactive extends ForegroundPauseResult {
  const ForegroundAlreadyInactive();
}

final class ForegroundPauseFailed extends ForegroundPauseResult {
  const ForegroundPauseFailed({required this.mayStillBeScanning});
  final bool mayStillBeScanning;
}

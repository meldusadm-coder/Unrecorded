import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import '../../services/notification_status_provider.dart';
import '../../services/protection_orchestrator_providers.dart';
import '../../services/protection_state.dart';
import '../../services/recent_risk_controller.dart';
import '../../services/recent_risk_visibility.dart';
import '../../services/scanner_provider.dart';
import 'protection_accent.dart';
import 'scan_state.dart';

/// Compact hero kind for the main protection screen.
enum MainScreenHeroKind {
  off,
  transition,
  protecting,
  possibleRisk,
  actionNeeded,
  error,
}

/// Primary protection-control action on the main screen.
enum MainScreenPrimaryAction {
  turnOn,
  turnOff,
  turningOff,
  tryAgain,
  openSettings,
  restartBackground,
}

/// Supplementary notice row kind (at most one shown).
enum MainScreenNoticeKind {
  recovery,
  notificationsOff,
  recentRisk,
}

/// Compact background-mode toggle presentation.
enum BackgroundToggleStatus {
  hidden,
  preferredNextTime,
  switching,
  activeInBackground,
  unavailable,
}

/// Pure presentation model for the glance-first main protection screen.
class MainScreenUiState {
  const MainScreenUiState({
    required this.heroKind,
    required this.heroTitle,
    required this.activityLine,
    required this.accent,
    required this.primaryAction,
    required this.primaryEnabled,
    required this.primaryLabel,
    required this.backgroundPreferred,
    required this.backgroundToggleEnabled,
    required this.backgroundToggleStatus,
    required this.suppressAds,
    required this.showLiveAlertActions,
    required this.isDemoMode,
    required this.showFeedbackLink,
    this.secondaryAction,
    this.secondaryLabel,
    this.noticeKind,
    this.noticeMessage,
    this.noticeActionLabel,
    this.alertDeviceTitle,
    this.riskLevel = RiskLevel.low,
    this.semanticLiveRegion = false,
  });

  final MainScreenHeroKind heroKind;
  final String heroTitle;
  final String activityLine;
  final ProtectionAccent accent;
  final MainScreenPrimaryAction primaryAction;
  final bool primaryEnabled;
  final String primaryLabel;
  final MainScreenPrimaryAction? secondaryAction;
  final String? secondaryLabel;
  final bool backgroundPreferred;
  final bool backgroundToggleEnabled;
  final BackgroundToggleStatus backgroundToggleStatus;
  final MainScreenNoticeKind? noticeKind;
  final String? noticeMessage;
  final String? noticeActionLabel;
  final bool showLiveAlertActions;
  final String? alertDeviceTitle;
  final RiskLevel riskLevel;
  final bool suppressAds;
  final bool isDemoMode;
  final bool showFeedbackLink;
  final bool semanticLiveRegion;

  String get backgroundToggleSubtitle => switch (backgroundToggleStatus) {
        BackgroundToggleStatus.hidden => '',
        BackgroundToggleStatus.preferredNextTime => 'Preferred for next time',
        BackgroundToggleStatus.switching => 'Switching…',
        BackgroundToggleStatus.activeInBackground => 'Active in background',
        BackgroundToggleStatus.unavailable => 'Unavailable on this device',
      };

  String get semanticLabel {
    final demo = isDemoMode ? 'Demo mode. ' : '';
    return '$demo$heroTitle. $activityLine';
  }
}

/// Inputs for [mapMainScreenUiState] — kept free of Flutter so unit tests stay pure.
class MainScreenUiInputs {
  const MainScreenUiInputs({
    required this.orchestrator,
    required this.scan,
    required this.isAndroid,
    this.notificationsOsEnabled,
    this.recentRiskVisible = false,
    this.recentRiskWindowLabel = '30 minutes',
  });

  final ProtectionOrchestratorState orchestrator;
  final ScanState scan;
  final bool isAndroid;
  final bool? notificationsOsEnabled;
  final bool recentRiskVisible;
  final String recentRiskWindowLabel;
}

/// Maps orchestrator + scan + OS inputs to [MainScreenUiState] with plan §11 precedence.
MainScreenUiState mapMainScreenUiState(MainScreenUiInputs inputs) {
  final orch = inputs.orchestrator;
  final scan = inputs.scan;
  final preferred = orch.lastConfirmedTuple?.backgroundModePreferred == true;
  final busy = orch.isBusy;
  final liveAlert = _isFreshLiveAlert(orch, scan);

  // Cold reconcile while off should remain glanceably Off (not a Stop control).
  if (orch.transition == ProtectionTransitionPhase.reconciling &&
      _effectivelyOff(orch) &&
      !scan.protectionRequested) {
    return _offState(
      preferred: preferred,
      isAndroid: inputs.isAndroid,
      isDemo: scan.isDemoMode,
    );
  }

  // --- Precedence branches ---

  if (_isActiveTransition(orch.transition)) {
    return _transitionState(
      orch: orch,
      preferred: preferred,
      isAndroid: inputs.isAndroid,
      liveAlert: liveAlert,
      scan: scan,
      isDemo: scan.isDemoMode,
    );
  }

  if (liveAlert) {
    final recovery = _highestPriorityIssue(orch, scan, inputs);
    return _possibleRiskState(
      scan: scan,
      preferred: preferred,
      isAndroid: inputs.isAndroid,
      busy: busy,
      notice: recovery,
      isDemo: scan.isDemoMode,
    );
  }

  final issuePresentation = _issuePresentation(orch, scan, inputs);
  if (issuePresentation != null) {
    return issuePresentation;
  }

  if (orch.confirmedOwner != ScannerOwner.none ||
      (scan.protectionActive && scan.protectionRequested) ||
      orch.foregroundMechanics == ForegroundMechanics.active ||
      orch.backgroundMechanics == BackgroundServiceMechanics.ready) {
    return _protectingState(
      orch: orch,
      scan: scan,
      preferred: preferred,
      isAndroid: inputs.isAndroid,
      notificationsOsEnabled: inputs.notificationsOsEnabled,
      recentRiskVisible: inputs.recentRiskVisible,
      recentRiskWindowLabel: inputs.recentRiskWindowLabel,
      isDemo: scan.isDemoMode,
    );
  }

  if (orch.foregroundMechanics == ForegroundMechanics.starting ||
      orch.backgroundMechanics == BackgroundServiceMechanics.starting ||
      orch.backgroundMechanics == BackgroundServiceMechanics.runningUnready ||
      scan.status == ScanStatus.starting) {
    return _startingState(
      preferred: preferred,
      isAndroid: inputs.isAndroid,
      isDemo: scan.isDemoMode,
    );
  }

  return _offState(
    preferred: preferred,
    isAndroid: inputs.isAndroid,
    isDemo: scan.isDemoMode,
  );
}

bool _isActiveTransition(ProtectionTransitionPhase phase) {
  return phase != ProtectionTransitionPhase.idle &&
      phase != ProtectionTransitionPhase.disposing;
}

bool _effectivelyOff(ProtectionOrchestratorState orch) {
  return orch.confirmedOwner == ScannerOwner.none &&
      !orch.foregroundMayBeActive &&
      !orch.backgroundMayBeActive &&
      orch.foregroundMechanics == ForegroundMechanics.inactive &&
      (orch.backgroundMechanics == BackgroundServiceMechanics.stopped ||
          orch.backgroundMechanics ==
              BackgroundServiceMechanics.unresponsive) &&
      (orch.lastConfirmedTuple == null ||
          !orch.lastConfirmedTuple!.protectionEnabled);
}

bool _isFreshLiveAlert(ProtectionOrchestratorState orch, ScanState scan) {
  if (!scan.showsRiskAlert) return false;
  // Stop / mechanics loss invalidates stale alert presentation.
  if (orch.transition == ProtectionTransitionPhase.finalisingStop) {
    return false;
  }
  if (_effectivelyOff(orch) && !scan.protectionRequested) {
    return false;
  }
  // Local protection activity (including demo harness) keeps the alert live
  // even when orchestrator ownership has not yet been mirrored.
  if (scan.protectionRequested && scan.showsRiskAlert) return true;
  return orch.confirmedOwner != ScannerOwner.none ||
      orch.foregroundMayBeActive ||
      orch.backgroundMayBeActive;
}

MainScreenUiState _transitionState({
  required ProtectionOrchestratorState orch,
  required bool preferred,
  required bool isAndroid,
  required bool liveAlert,
  required ScanState scan,
  required bool isDemo,
}) {
  final phase = orch.transition;
  final (title, activity) = switch (phase) {
    ProtectionTransitionPhase.enablingForeground ||
    ProtectionTransitionPhase.enablingBackground =>
      (
        'Turning on protection',
        'Starting nearby check…',
      ),
    ProtectionTransitionPhase.switchingToBackground => (
        'Switching to background',
        'Moving nearby checks to the background…',
      ),
    ProtectionTransitionPhase.switchingToForeground => (
        'Switching to foreground',
        'Moving nearby checks into the open app…',
      ),
    ProtectionTransitionPhase.reconciling => (
        'Updating protection',
        'Checking protection status…',
      ),
    ProtectionTransitionPhase.rollingBack => (
        'Adjusting protection',
        'Finishing a previous change…',
      ),
    ProtectionTransitionPhase.finalisingStop => (
        'Turning off protection',
        'Stopping nearby-device checks…',
      ),
    _ => (
        'Updating protection',
        'Starting nearby check…',
      ),
  };

  final stopping = phase == ProtectionTransitionPhase.finalisingStop;

  return MainScreenUiState(
    heroKind: MainScreenHeroKind.transition,
    heroTitle: title,
    activityLine: activity,
    accent: ProtectionAccent.primary,
    primaryAction: stopping
        ? MainScreenPrimaryAction.turningOff
        : MainScreenPrimaryAction.turnOff,
    primaryEnabled: !stopping,
    primaryLabel: stopping ? 'Turning off…' : AppCopy.turnOffProtection,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: false,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: isAndroid,
      preferred: preferred,
      busy: true,
      activeBackground: orch.confirmedOwner == ScannerOwner.background,
    ),
    suppressAds: true,
    showLiveAlertActions: liveAlert,
    alertDeviceTitle: liveAlert && scan.possibleRiskSignals.isNotEmpty
        ? scan.possibleRiskSignals.first.title
        : null,
    riskLevel: scan.riskLevel,
    isDemoMode: isDemo,
    showFeedbackLink: !liveAlert,
    semanticLiveRegion: liveAlert,
  );
}

MainScreenUiState _possibleRiskState({
  required ScanState scan,
  required bool preferred,
  required bool isAndroid,
  required bool busy,
  required _NoticeBits? notice,
  required bool isDemo,
}) {
  final deviceTitle = scan.possibleRiskSignals.isEmpty
      ? null
      : scan.possibleRiskSignals.first.title;
  final accent = scan.riskLevel == RiskLevel.high
      ? ProtectionAccent.danger
      : ProtectionAccent.warning;

  return MainScreenUiState(
    heroKind: MainScreenHeroKind.possibleRisk,
    heroTitle: AppCopy.possibleRiskTitle,
    activityLine: 'Possible recording risk noticed nearby',
    accent: accent,
    primaryAction: MainScreenPrimaryAction.turnOff,
    primaryEnabled: !busy,
    primaryLabel: AppCopy.turnOffProtection,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: isAndroid && !busy,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: isAndroid,
      preferred: preferred,
      busy: busy,
      activeBackground: false,
    ),
    noticeKind: notice?.kind,
    noticeMessage: notice?.message,
    noticeActionLabel: notice?.actionLabel,
    secondaryAction: notice?.secondaryAction,
    secondaryLabel: notice?.secondaryLabel,
    suppressAds: true,
    showLiveAlertActions: true,
    alertDeviceTitle: deviceTitle,
    riskLevel: scan.riskLevel,
    isDemoMode: isDemo,
    showFeedbackLink: false,
    semanticLiveRegion: true,
  );
}

MainScreenUiState? _issuePresentation(
  ProtectionOrchestratorState orch,
  ScanState scan,
  MainScreenUiInputs inputs,
) {
  final bits = _highestPriorityIssue(orch, scan, inputs);
  if (bits == null || bits.kind != MainScreenNoticeKind.recovery) {
    // Scan-level blocks without orchestrator issue still need action-needed hero.
    if (scan.isBlocked || scan.status == ScanStatus.error) {
      return _actionNeededFromScan(scan, inputs);
    }
    return null;
  }

  final preferred = orch.lastConfirmedTuple?.backgroundModePreferred == true;
  return MainScreenUiState(
    heroKind: bits.heroKind,
    heroTitle: bits.heroTitle ?? 'Action needed',
    activityLine: bits.message,
    accent: bits.accent,
    primaryAction: bits.primaryAction,
    primaryEnabled: true,
    primaryLabel: bits.primaryLabel,
    secondaryAction: bits.secondaryAction,
    secondaryLabel: bits.secondaryLabel,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: inputs.isAndroid &&
        bits.primaryAction != MainScreenPrimaryAction.turningOff,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: inputs.isAndroid,
      preferred: preferred,
      busy: orch.isBusy,
      activeBackground: orch.confirmedOwner == ScannerOwner.background,
    ),
    noticeKind: null,
    suppressAds: true,
    showLiveAlertActions: false,
    riskLevel: scan.riskLevel,
    isDemoMode: scan.isDemoMode,
    showFeedbackLink: true,
  );
}

MainScreenUiState _actionNeededFromScan(
  ScanState scan,
  MainScreenUiInputs inputs,
) {
  final preferred =
      inputs.orchestrator.lastConfirmedTuple?.backgroundModePreferred == true;
  final (title, activity, action, label) = switch (scan.status) {
    ScanStatus.permissionDenied => (
        AppCopy.permissionRequiredTitle,
        scan.statusMessage ?? AppCopy.permissionHelper,
        MainScreenPrimaryAction.tryAgain,
        'Try again',
      ),
    ScanStatus.permissionPermanentlyDenied => (
        AppCopy.permissionRequiredTitle,
        scan.statusMessage ?? AppCopy.permissionPermanentlyDeniedHelper,
        MainScreenPrimaryAction.openSettings,
        'Open app settings',
      ),
    ScanStatus.bluetoothOff => (
        'Bluetooth is off',
        scan.statusMessage ?? AppCopy.bluetoothOffMessage,
        MainScreenPrimaryAction.tryAgain,
        'Try again',
      ),
    ScanStatus.bluetoothUnsupported => (
        'Bluetooth not supported',
        scan.statusMessage ?? AppCopy.bluetoothUnsupportedMessage,
        MainScreenPrimaryAction.turnOff,
        AppCopy.turnOffProtection,
      ),
    ScanStatus.error => (
        'Scan issue',
        scan.statusMessage ?? AppCopy.scanErrorMessage,
        MainScreenPrimaryAction.tryAgain,
        'Try again',
      ),
    _ => (
        'Action needed',
        scan.statusMessage ?? AppCopy.permissionHelper,
        MainScreenPrimaryAction.openSettings,
        'Open app settings',
      ),
  };

  return MainScreenUiState(
    heroKind: scan.status == ScanStatus.error
        ? MainScreenHeroKind.error
        : MainScreenHeroKind.actionNeeded,
    heroTitle: title,
    activityLine: activity,
    accent: scan.status == ScanStatus.error
        ? ProtectionAccent.muted
        : ProtectionAccent.info,
    primaryAction: action,
    primaryEnabled: true,
    primaryLabel: label,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: false,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: inputs.isAndroid,
      preferred: preferred,
      busy: false,
      activeBackground: false,
    ),
    suppressAds: true,
    showLiveAlertActions: false,
    riskLevel: scan.riskLevel,
    isDemoMode: scan.isDemoMode,
    showFeedbackLink: true,
  );
}

MainScreenUiState _protectingState({
  required ProtectionOrchestratorState orch,
  required ScanState scan,
  required bool preferred,
  required bool isAndroid,
  required bool? notificationsOsEnabled,
  required bool recentRiskVisible,
  required String recentRiskWindowLabel,
  required bool isDemo,
}) {
  final backgroundOwner = orch.confirmedOwner == ScannerOwner.background ||
      orch.backgroundMechanics == BackgroundServiceMechanics.ready;
  final activity = switch (scan.status) {
    ScanStatus.resting => 'Resting briefly before the next check',
    ScanStatus.confirmingRisk => 'Checking a possible match',
    _ when backgroundOwner => 'Checking nearby signals in the background',
    _ => 'Checking nearby signals while the app is open',
  };

  MainScreenNoticeKind? noticeKind;
  String? noticeMessage;
  String? noticeActionLabel;

  if (notificationsOsEnabled == false) {
    noticeKind = MainScreenNoticeKind.notificationsOff;
    noticeMessage = 'Notifications are off';
    noticeActionLabel = 'Open app settings';
  } else if (recentRiskVisible) {
    noticeKind = MainScreenNoticeKind.recentRisk;
    noticeMessage = AppCopy.recentRiskCardBody(recentRiskWindowLabel);
    noticeActionLabel = 'View details';
  }

  return MainScreenUiState(
    heroKind: MainScreenHeroKind.protecting,
    heroTitle: 'Protecting',
    activityLine: activity,
    accent: ProtectionAccent.primary,
    primaryAction: MainScreenPrimaryAction.turnOff,
    primaryEnabled: true,
    primaryLabel: AppCopy.turnOffProtection,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: isAndroid,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: isAndroid,
      preferred: preferred,
      busy: false,
      activeBackground: backgroundOwner,
    ),
    noticeKind: noticeKind,
    noticeMessage: noticeMessage,
    noticeActionLabel: noticeActionLabel,
    suppressAds: false,
    showLiveAlertActions: false,
    riskLevel: scan.riskLevel,
    isDemoMode: isDemo,
    showFeedbackLink: true,
  );
}

MainScreenUiState _startingState({
  required bool preferred,
  required bool isAndroid,
  required bool isDemo,
}) {
  return MainScreenUiState(
    heroKind: MainScreenHeroKind.transition,
    heroTitle: 'Turning on protection',
    activityLine: 'Starting nearby check…',
    accent: ProtectionAccent.primary,
    primaryAction: MainScreenPrimaryAction.turnOff,
    primaryEnabled: true,
    primaryLabel: AppCopy.turnOffProtection,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: false,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: isAndroid,
      preferred: preferred,
      busy: true,
      activeBackground: false,
    ),
    suppressAds: true,
    showLiveAlertActions: false,
    isDemoMode: isDemo,
    showFeedbackLink: true,
  );
}

MainScreenUiState _offState({
  required bool preferred,
  required bool isAndroid,
  required bool isDemo,
}) {
  return MainScreenUiState(
    heroKind: MainScreenHeroKind.off,
    heroTitle: 'Protection is off',
    activityLine: 'No nearby-device check is running',
    accent: ProtectionAccent.muted,
    primaryAction: MainScreenPrimaryAction.turnOn,
    primaryEnabled: true,
    primaryLabel: AppCopy.turnOnProtection,
    backgroundPreferred: preferred,
    backgroundToggleEnabled: isAndroid,
    backgroundToggleStatus: _toggleStatus(
      isAndroid: isAndroid,
      preferred: preferred,
      busy: false,
      activeBackground: false,
    ),
    suppressAds: false,
    showLiveAlertActions: false,
    isDemoMode: isDemo,
    showFeedbackLink: true,
  );
}

BackgroundToggleStatus _toggleStatus({
  required bool isAndroid,
  required bool preferred,
  required bool busy,
  required bool activeBackground,
}) {
  if (!isAndroid) return BackgroundToggleStatus.hidden;
  if (busy) return BackgroundToggleStatus.switching;
  if (activeBackground) return BackgroundToggleStatus.activeInBackground;
  if (preferred) return BackgroundToggleStatus.preferredNextTime;
  return BackgroundToggleStatus.preferredNextTime;
}

class _NoticeBits {
  const _NoticeBits({
    required this.kind,
    required this.message,
    required this.primaryAction,
    required this.primaryLabel,
    required this.accent,
    required this.heroKind,
    this.actionLabel,
    this.heroTitle,
    this.secondaryAction,
    this.secondaryLabel,
  });

  final MainScreenNoticeKind kind;
  final String message;
  final String? actionLabel;
  final MainScreenPrimaryAction primaryAction;
  final String primaryLabel;
  final ProtectionAccent accent;
  final MainScreenHeroKind heroKind;
  final String? heroTitle;
  final MainScreenPrimaryAction? secondaryAction;
  final String? secondaryLabel;
}

_NoticeBits? _highestPriorityIssue(
  ProtectionOrchestratorState orch,
  ScanState scan,
  MainScreenUiInputs inputs,
) {
  final issue = orch.issue;
  if (issue == BackgroundProtectionIssue.serviceStopFailed ||
      issue == BackgroundProtectionIssue.serviceUnresponsive) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: 'Could not fully turn off protection. Try again.',
      actionLabel: 'Try again',
      primaryAction: MainScreenPrimaryAction.tryAgain,
      primaryLabel: 'Try again',
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Action needed',
    );
  }
  if (issue == BackgroundProtectionIssue.protocolPersistenceFailed ||
      issue == BackgroundProtectionIssue.protocolUnavailable) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: 'Protection settings could not be saved. Try again.',
      actionLabel: 'Try again',
      primaryAction: MainScreenPrimaryAction.tryAgain,
      primaryLabel: 'Try again',
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Action needed',
      secondaryAction: MainScreenPrimaryAction.turnOff,
      secondaryLabel: AppCopy.turnOffProtection,
    );
  }
  if (issue == BackgroundProtectionIssue.foregroundStartFailed ||
      issue == BackgroundProtectionIssue.foregroundPauseFailed ||
      issue == BackgroundProtectionIssue.foregroundStopFailed) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: 'Foreground protection could not finish. Try again.',
      actionLabel: 'Try again',
      primaryAction: MainScreenPrimaryAction.tryAgain,
      primaryLabel: 'Try again',
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Action needed',
    );
  }
  if (issue == BackgroundProtectionIssue.androidStoppedBackgroundProtection) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: AppCopy.backgroundProtectionStoppedByAndroid,
      actionLabel: AppCopy.backgroundProtectionRestart,
      primaryAction: MainScreenPrimaryAction.restartBackground,
      primaryLabel: AppCopy.backgroundProtectionRestart,
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Background protection stopped',
    );
  }
  if (issue == BackgroundProtectionIssue.serviceStartFailed) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: 'Background protection could not start',
      actionLabel: AppCopy.backgroundProtectionRestart,
      primaryAction: MainScreenPrimaryAction.restartBackground,
      primaryLabel: AppCopy.backgroundProtectionRestart,
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Background protection could not start',
      secondaryAction: MainScreenPrimaryAction.turnOff,
      secondaryLabel: AppCopy.turnOffProtection,
    );
  }
  if (issue == BackgroundProtectionIssue.mainPreflightFailed ||
      issue == BackgroundProtectionIssue.taskBlocked ||
      issue == BackgroundProtectionIssue.backgroundNotSupported ||
      issue == BackgroundProtectionIssue.leaseAcquireFailed ||
      issue == BackgroundProtectionIssue.readinessTimeout ||
      issue == BackgroundProtectionIssue.staleStartCleanupPending ||
      issue == BackgroundProtectionIssue.backgroundSwitchFailed ||
      issue == BackgroundProtectionIssue.inconsistentLegacyCleanup ||
      issue == BackgroundProtectionIssue.unknown) {
    return _NoticeBits(
      kind: MainScreenNoticeKind.recovery,
      message: scan.statusMessage ?? 'Protection needs attention.',
      actionLabel: 'Try again',
      primaryAction: MainScreenPrimaryAction.tryAgain,
      primaryLabel: 'Try again',
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.actionNeeded,
      heroTitle: 'Action needed',
    );
  }

  if (scan.isBlocked || scan.status == ScanStatus.error) {
    // Handled by dedicated scan mapping when not used as supplementary row.
    return null;
  }

  if (inputs.notificationsOsEnabled == false &&
      (orch.confirmedOwner != ScannerOwner.none || scan.protectionActive)) {
    return const _NoticeBits(
      kind: MainScreenNoticeKind.notificationsOff,
      message: 'Notifications are off',
      actionLabel: 'Open app settings',
      primaryAction: MainScreenPrimaryAction.openSettings,
      primaryLabel: 'Open app settings',
      accent: ProtectionAccent.info,
      heroKind: MainScreenHeroKind.protecting,
    );
  }

  return null;
}

/// Riverpod provider composing live inputs into [MainScreenUiState].
final mainScreenUiStateProvider = Provider<MainScreenUiState>((ref) {
  final orch = ref.watch(protectionOrchestratorProvider);
  final scan = ref.watch(scanControllerProvider);
  final isAndroid = ref.watch(scanRuntimeProvider).isAndroid;
  final recent = ref.watch(recentRiskVisibleProvider);
  final recentWindow = ref.watch(recentRiskControllerProvider).window.label;
  final osEnabledAsync = ref.watch(notificationsOsEnabledProvider);
  final notificationsOsEnabled = osEnabledAsync.asData?.value;

  return mapMainScreenUiState(
    MainScreenUiInputs(
      orchestrator: orch,
      scan: scan,
      isAndroid: isAndroid,
      notificationsOsEnabled: notificationsOsEnabled,
      recentRiskVisible: recent != null,
      recentRiskWindowLabel: recentWindow,
    ),
  );
});

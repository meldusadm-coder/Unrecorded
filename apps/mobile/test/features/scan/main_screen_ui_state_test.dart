import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/main_screen_ui_state.dart';
import 'package:unrecorded_mobile/features/scan/protection_accent.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/protection_protocol_models.dart';
import 'package:unrecorded_mobile/services/protection_state.dart';

void main() {
  const offOrch = ProtectionOrchestratorState();

  group('mapMainScreenUiState', () {
    test('off when idle and orchestrator stable off', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: offOrch,
          scan: ScanState(),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.off);
      expect(ui.heroTitle, 'Protection is off');
      expect(ui.primaryAction, MainScreenPrimaryAction.turnOn);
      expect(ui.primaryLabel, AppCopy.turnOnProtection);
      expect(ui.suppressAds, isFalse);
      expect(ui.accent, ProtectionAccent.muted);
    });

    test('protecting for foreground scanning', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.protecting);
      expect(ui.heroTitle, 'Protecting');
      expect(ui.activityLine, 'Checking nearby signals while the app is open');
      expect(ui.primaryLabel, AppCopy.turnOffProtection);
      expect(ui.suppressAds, isFalse);
    });

    test('protecting for background owner', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.background,
            backgroundMechanics: BackgroundServiceMechanics.ready,
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.activityLine, 'Checking nearby signals in the background');
      expect(
        ui.backgroundToggleStatus,
        BackgroundToggleStatus.activeInBackground,
      );
    });

    test('transition enabling suppresses ads and keeps stop available', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            transition: ProtectionTransitionPhase.enablingForeground,
            activeOperationId: 'op-1',
          ),
          scan:
              ScanState(status: ScanStatus.starting, protectionRequested: true),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.transition);
      expect(ui.heroTitle, 'Turning on protection');
      expect(ui.primaryAction, MainScreenPrimaryAction.turnOff);
      expect(ui.primaryEnabled, isTrue);
      expect(ui.suppressAds, isTrue);
    });

    test('finalising stop keeps primary tappable and labels Turning off', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            transition: ProtectionTransitionPhase.finalisingStop,
            activeOperationId: 'op-stop',
          ),
          scan:
              ScanState(status: ScanStatus.scanning, protectionRequested: true),
          isAndroid: true,
        ),
      );
      expect(ui.primaryAction, MainScreenPrimaryAction.turningOff);
      expect(ui.primaryEnabled, isTrue);
      expect(ui.primaryLabel, 'Turning off…');
      expect(ui.suppressAds, isTrue);
    });

    test('protecting always enables Turn off', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
            retainedCleanup: true,
            activeOperationId: 'stale-op',
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
        ),
      );
      // retainedCleanup alone without active transition still reaches protecting
      // only when transition is idle — force idle-compatible busy flags via owner.
      expect(ui.heroKind, MainScreenHeroKind.protecting);
      expect(ui.primaryAction, MainScreenPrimaryAction.turnOff);
      expect(ui.primaryEnabled, isTrue);
    });

    test('stale mirrored scan does not keep Protecting after explicit Stop',
        () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            lastConfirmedTuple: ProtectionProtocolTuple(
              schemaVersion: 1,
              revision: 3,
              backgroundModePreferred: true,
              protectionEnabled: false,
              backgroundRuntimeEnabled: false,
              explicitlyStopped: true,
              activeTaskSessionId: null,
              activeTaskEpoch: null,
              activeTaskIncarnationId: null,
              nextTaskGeneration: 2,
              activeStartAttemptId: null,
              activeStartProcessId: null,
              taskPhase: ProtocolTaskPhase.none,
              nativeStartUnresolved: false,
            ),
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.off);
      expect(ui.primaryAction, MainScreenPrimaryAction.turnOn);
      expect(ui.primaryLabel, AppCopy.turnOnProtection);
    });

    test('live possible-risk owns hero and suppresses ads', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
          ),
          scan: ScanState(
            status: ScanStatus.possibleRiskDetected,
            protectionRequested: true,
            riskLevel: RiskLevel.high,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.possibleRisk);
      expect(ui.showLiveAlertActions, isTrue);
      expect(ui.showFeedbackLink, isFalse);
      expect(ui.suppressAds, isTrue);
      expect(ui.accent, ProtectionAccent.danger);
      expect(ui.activityLine, 'Possible recording risk noticed nearby');
    });

    test('serviceStopFailed outranks calm protecting', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
            issue: BackgroundProtectionIssue.serviceStopFailed,
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.actionNeeded);
      expect(ui.primaryAction, MainScreenPrimaryAction.tryAgain);
      expect(ui.suppressAds, isTrue);
    });

    test('permission denied maps to action needed', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: offOrch,
          scan: ScanState(status: ScanStatus.permissionDenied),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.actionNeeded);
      expect(ui.accent, ProtectionAccent.info);
      expect(ui.primaryAction, MainScreenPrimaryAction.tryAgain);
      expect(ui.suppressAds, isTrue);
    });

    test('notifications off uses supplementary row while protecting', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
          notificationsOsEnabled: false,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.protecting);
      expect(ui.noticeKind, MainScreenNoticeKind.notificationsOff);
      expect(ui.noticeActionLabel, 'Open app settings');
    });

    test('recent risk notice only when no higher priority issue', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: ProtectionOrchestratorState(
            confirmedOwner: ScannerOwner.foreground,
            foregroundMechanics: ForegroundMechanics.active,
          ),
          scan: ScanState(
            status: ScanStatus.scanning,
            protectionRequested: true,
          ),
          isAndroid: true,
          notificationsOsEnabled: true,
          recentRiskVisible: true,
          recentRiskWindowLabel: '30 minutes',
        ),
      );
      expect(ui.noticeKind, MainScreenNoticeKind.recentRisk);
      expect(ui.noticeMessage, contains('30 minutes'));
    });

    test('stale alert after stable off is not shown', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: offOrch,
          scan: ScanState(
            status: ScanStatus.possibleRiskDetected,
            alertDismissed: false,
          ),
          isAndroid: true,
        ),
      );
      expect(ui.heroKind, MainScreenHeroKind.off);
      expect(ui.showLiveAlertActions, isFalse);
    });

    test('hides background toggle off Android', () {
      final ui = mapMainScreenUiState(
        const MainScreenUiInputs(
          orchestrator: offOrch,
          scan: ScanState(),
          isAndroid: false,
        ),
      );
      expect(ui.backgroundToggleStatus, BackgroundToggleStatus.hidden);
    });
  });
}

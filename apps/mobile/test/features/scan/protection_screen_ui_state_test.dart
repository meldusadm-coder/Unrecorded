import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/protection_screen_ui_state.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';

void main() {
  group('ProtectionScreenUiState', () {
    test('collapses routine scan phases into protection on', () {
      for (final status in [
        ScanStatus.scanning,
        ScanStatus.resting,
        ScanStatus.confirmingRisk,
      ]) {
        final ui = ProtectionScreenUiState.fromScanState(
          ScanState(status: status, protectionRequested: true),
        );

        expect(ui.controlLabel, 'Protection On');
        expect(ui.statusTitle, 'Protection is on');
        expect(
          ui.supportingText,
          'Checking nearby Bluetooth signals for possible recording wearables.',
        );
        expect(ui.showsRiskAlert, isFalse);
      }
    });

    test('shows clear off and starting states', () {
      final off = ProtectionScreenUiState.fromScanState(const ScanState());
      expect(off.controlLabel, 'Protection Off');
      expect(off.statusTitle, 'Protection is off');
      expect(off.supportingText, contains('Turn on protection'));

      final starting = ProtectionScreenUiState.fromScanState(
        const ScanState(
          status: ScanStatus.starting,
          protectionRequested: true,
        ),
      );
      expect(starting.controlLabel, 'Protection On');
      expect(starting.statusTitle, 'Starting protection…');
      expect(starting.primaryActionEnabled, isFalse);
    });

    test('turns permissions and Bluetooth blockers into actionable states', () {
      for (final status in [
        ScanStatus.permissionDenied,
        ScanStatus.permissionPermanentlyDenied,
        ScanStatus.bluetoothOff,
        ScanStatus.bluetoothUnsupported,
      ]) {
        final ui = ProtectionScreenUiState.fromScanState(
          ScanState(status: status, statusMessage: 'Fix this setting.'),
        );

        expect(ui.controlLabel, 'Protection Off');
        expect(ui.statusTitle, 'Bluetooth or permission required');
        expect(ui.supportingText, 'Fix this setting.');
        expect(ui.actionLabel, 'Open settings');
        expect(ui.primaryActionEnabled, isFalse);
      }
    });

    test('surfaces retryable errors', () {
      final ui = ProtectionScreenUiState.fromScanState(
        const ScanState(status: ScanStatus.error),
      );

      expect(ui.statusTitle, 'Protection needs attention');
      expect(ui.actionLabel, 'Try again');
    });

    test('elevates possible risk while keeping protection visible', () {
      final ui = ProtectionScreenUiState.fromScanState(
        const ScanState(
          status: ScanStatus.possibleRiskDetected,
          protectionRequested: true,
          riskLevel: RiskLevel.medium,
        ),
      );

      expect(ui.controlLabel, 'Protection On');
      expect(ui.statusTitle, AppCopy.possibleRiskTitle);
      expect(ui.protectionLine, 'Protection is on');
      expect(ui.supportingText, contains('not proof'));
      expect(ui.showsRiskAlert, isTrue);
      expect(ui.actionLabel, 'View details');
    });

    test('keeps dismissed live risk visible without the alert card', () {
      final ui = ProtectionScreenUiState.fromScanState(
        const ScanState(
          status: ScanStatus.possibleRiskDetected,
          protectionRequested: true,
          alertDismissed: true,
        ),
      );

      expect(ui.statusTitle, AppCopy.possibleRiskTitle);
      expect(ui.showsRiskAlert, isFalse);
      expect(ui.actionLabel, 'View details');
    });
  });
}

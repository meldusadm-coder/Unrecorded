import 'package:unrecorded_core/unrecorded_core.dart';

import 'scan_state.dart';

class ProtectionScreenUiState {
  const ProtectionScreenUiState({
    required this.controlLabel,
    required this.primaryActionEnabled,
    required this.statusTitle,
    required this.supportingText,
    required this.protectionLine,
    required this.showsRiskAlert,
    this.actionLabel,
  });

  final String controlLabel;
  final bool primaryActionEnabled;
  final String statusTitle;
  final String supportingText;
  final String protectionLine;
  final bool showsRiskAlert;
  final String? actionLabel;

  factory ProtectionScreenUiState.fromScanState(ScanState state) {
    if (state.status == ScanStatus.possibleRiskDetected) {
      return ProtectionScreenUiState(
        controlLabel: AppCopy.protectionControlOn,
        primaryActionEnabled: true,
        statusTitle: AppCopy.possibleRiskTitle,
        supportingText: AppCopy.protectionPossibleRiskBody,
        protectionLine: AppCopy.protectionOnTitle,
        showsRiskAlert: !state.alertDismissed,
        actionLabel: 'View details',
      );
    }

    if (state.status == ScanStatus.starting) {
      return const ProtectionScreenUiState(
        controlLabel: AppCopy.protectionControlOn,
        primaryActionEnabled: false,
        statusTitle: AppCopy.protectionStartingTitle,
        supportingText: AppCopy.protectionStartingBody,
        protectionLine: AppCopy.protectionOnTitle,
        showsRiskAlert: false,
      );
    }

    if (state.isBlocked) {
      return ProtectionScreenUiState(
        controlLabel: AppCopy.protectionControlOff,
        primaryActionEnabled: false,
        statusTitle: AppCopy.protectionActionRequiredTitle,
        supportingText: state.statusMessage ?? AppCopy.permissionHelper,
        protectionLine: AppCopy.protectionOffTitle,
        showsRiskAlert: false,
        actionLabel: 'Open settings',
      );
    }

    if (state.status == ScanStatus.error) {
      return ProtectionScreenUiState(
        controlLabel: AppCopy.protectionControlOff,
        primaryActionEnabled: true,
        statusTitle: AppCopy.protectionErrorTitle,
        supportingText: state.statusMessage ?? AppCopy.scanErrorMessage,
        protectionLine: AppCopy.protectionOffTitle,
        showsRiskAlert: false,
        actionLabel: 'Try again',
      );
    }

    if (state.protectionActive) {
      return const ProtectionScreenUiState(
        controlLabel: AppCopy.protectionControlOn,
        primaryActionEnabled: true,
        statusTitle: AppCopy.protectionOnTitle,
        supportingText: AppCopy.protectionOnBody,
        protectionLine: AppCopy.protectionOnTitle,
        showsRiskAlert: false,
      );
    }

    return const ProtectionScreenUiState(
      controlLabel: AppCopy.protectionControlOff,
      primaryActionEnabled: true,
      statusTitle: AppCopy.protectionOffTitle,
      supportingText: AppCopy.protectionOffBody,
      protectionLine: AppCopy.protectionOffTitle,
      showsRiskAlert: false,
    );
  }
}

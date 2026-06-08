import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/copy/feedback_copy.dart';

import 'support/certainty_language.dart';

void main() {
  test('scan and alert copy avoids certainty wording', () {
    final copyStrings = <String>[
      AppCopy.scanHelper,
      AppCopy.scanningActive,
      AppCopy.scanResting,
      AppCopy.confirmingRisk,
      AppCopy.demoModeBanner,
      AppCopy.notProofOfRecording,
      AppCopy.noRiskWhileScanning,
      AppCopy.possibleRiskTitle,
      AppCopy.possibleRiskBody,
      AppCopy.alertCardTitle,
      AppCopy.alertCardBody,
      AppCopy.alertExampleFooter,
      AppCopy.riskResultHelper,
      AppCopy.permissionHelper,
      AppCopy.permissionPermanentlyDeniedHelper,
      AppCopy.bluetoothOffMessage,
      AppCopy.bluetoothUnsupportedMessage,
      AppCopy.scanErrorMessage,
      AppCopy.riskNotificationsSubtitle,
      AppCopy.riskNotificationLevelSubtitle,
      AppCopy.protectionStatusNotificationTitle,
      AppCopy.protectionStatusNotificationDefaultBody,
      AppCopy.protectionStatusNotificationScanningBody,
      AppCopy.notificationModeRiskAlertsOn,
      AppCopy.notificationModeProtectionStatusOn,
      AppCopy.notificationModeNotificationsOff,
      AppCopy.notificationModeScanningReliability,
      AppCopy.notificationPermissionDeniedHelper,
      AppCopy.notificationsHelpTitle,
      AppCopy.notificationsHelpBody,
      AppCopy.widgetPossibleRisk,
      AppCopy.widgetHelpTitle,
      AppCopy.widgetHelpBody,
      AppCopy.widgetHelpLimitations,
    ];

    for (final text in copyStrings) {
      expectNoCertaintyLanguage(text);
    }
  });

  test('feedback copy avoids certainty wording', () {
    final feedbackStrings = <String>[
      FeedbackCopy.intro,
      FeedbackCopy.privacyNote,
      FeedbackCopy.messageHelper,
      FeedbackCopy.diagnosticsSubtitle,
      FeedbackCopy.submitSuccess,
      FeedbackCopy.fallbackBody,
    ];

    for (final text in feedbackStrings) {
      expectNoCertaintyLanguage(text);
    }
  });

  test('privacy and detection limitation copy keeps uncertainty language', () {
    expect(
      PrivacyDisclaimer.detectionDisclaimer.toLowerCase(),
      contains('cannot prove'),
    );
    expect(AppCopy.notProofOfRecording.toLowerCase(), contains('not proof'));
    expect(
      AppCopy.riskResultHelper.toLowerCase(),
      contains('not that recording is confirmed'),
    );
    expectNoCertaintyLanguage(PrivacyDisclaimer.detectionDisclaimer);
    expectNoCertaintyLanguage(PrivacyDisclaimer.tagline);
    expectNoCertaintyLanguage(PrivacyDisclaimer.privacyModel);
  });
}

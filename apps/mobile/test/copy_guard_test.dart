import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

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
      AppCopy.widgetPossibleRisk,
    ];

    for (final text in copyStrings) {
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

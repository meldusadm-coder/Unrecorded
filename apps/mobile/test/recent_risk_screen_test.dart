import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/alerts/recent_risk_screen.dart';
import 'package:unrecorded_mobile/services/recent_risk_controller.dart';

void main() {
  final fixedNow = DateTime(2025, 6, 8, 12, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp(RecentRiskController controller) {
    return ProviderScope(
      overrides: [
        recentRiskControllerProvider.overrideWith((ref) => controller),
        clockProvider.overrideWith((ref) => () => fixedNow),
      ],
      child: const MaterialApp(home: RecentRiskScreen()),
    );
  }

  testWidgets('shows enum reason labels when present', (tester) async {
    final controller = RecentRiskController.forTesting(
      RecentRiskState(
        event: RecentRiskEvent(
          noticedAt: fixedNow.subtract(const Duration(minutes: 5)),
          riskLevel: RiskLevel.medium,
          reasons: const [RecentRiskReason.strongSignal],
        ),
      ),
      now: () => fixedNow,
    );

    await tester.pumpWidget(buildApp(controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(AppCopy.recentRiskReasonLabel(RecentRiskReason.strongSignal)),
      findsOneWidget,
    );
    expect(find.text(AppCopy.recentRiskGenericReason), findsNothing);
  });

  testWidgets('shows generic reason line when reasons empty', (tester) async {
    final controller = RecentRiskController.forTesting(
      RecentRiskState(
        event: RecentRiskEvent(
          noticedAt: fixedNow.subtract(const Duration(minutes: 5)),
          riskLevel: RiskLevel.medium,
        ),
      ),
      now: () => fixedNow,
    );

    await tester.pumpWidget(buildApp(controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppCopy.recentRiskGenericReason), findsOneWidget);
    expect(find.textContaining('Ray-Ban'), findsNothing);
  });
}

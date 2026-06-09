import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/services/widget_sync_service.dart';

void main() {
  const service = WidgetSyncService();

  test('live possibleRiskDetected shows live widget line', () {
    final state = const ScanState(status: ScanStatus.possibleRiskDetected);
    final lines = service.linesForState(state, recentRiskVisible: true);
    expect(lines.$1, AppCopy.widgetPossibleRisk);
  });

  test('non-live with visible recent event shows recent copy', () {
    final state = const ScanState(status: ScanStatus.resting);
    final lines = service.linesForState(state, recentRiskVisible: true);
    expect(lines.$1, AppCopy.widgetPossibleRiskRecent);
    expect(lines.$2, AppCopy.widgetOpenAppToView);
  });
}

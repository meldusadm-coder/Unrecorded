import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'features/scan/scan_state.dart';
import 'services/ads_service.dart';
import 'services/entitlement_service.dart';
import 'services/scanner_provider.dart';

/// App shell with a single shared bottom ad slot.
class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  bool _showAdSlot(WidgetRef ref) {
    if (ref.watch(adsRemovedProvider)) return false;

    if (location != '/') return true;

    final state = ref.watch(scanControllerProvider);
    final showAlert = state.status == ScanStatus.possibleRiskDetected &&
        !state.alertDismissed;
    if (showAlert) return false;
    if (state.isBlocked) return false;
    if (state.status == ScanStatus.error) return false;
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(child: child),
        BottomAdSlot(
          showSlot: _showAdSlot(ref),
          onRemoveAdsTap: () => context.push('/remove-ads'),
          child: ref.watch(bannerAdWidgetProvider),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'features/scan/main_screen_ui_state.dart';
import 'services/ads_service.dart';
import 'services/entitlement_service.dart';

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
    if (!ref.watch(adsMayShowProvider)) return false;

    if (location != '/') return true;

    final ui = ref.watch(mainScreenUiStateProvider);
    return !ui.suppressAds;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Column(
      children: [
        Expanded(child: child),
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: BottomAdSlot(
            showSlot: _showAdSlot(ref),
            onRemoveAdsTap: () => context.push('/remove-ads'),
            child: ref.watch(bannerAdWidgetProvider),
          ),
        ),
      ],
    );
  }
}

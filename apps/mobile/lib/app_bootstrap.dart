import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/scan/scan_state.dart';
import 'services/background_protection_controller.dart';
import 'services/background_protection_prefs.dart';
import 'services/protection_prefs.dart';
import 'services/recent_risk_controller.dart';
import 'services/risk_notification_service.dart';
import 'services/scanner_provider.dart';
import 'services/widget_sync_service.dart';

/// Initialises widget sync and restores protection if the user left it on.
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(recentRiskControllerProvider.notifier).reload();
    }
  }

  Future<void> _init() async {
    final notifications = ref.read(riskNotificationServiceProvider);
    await notifications.init();
    await notifications.handleNotificationLaunch();
    ref.read(widgetSyncServiceProvider);
    await ref.read(scannerConfigInitProvider.future);

    final bgPrefs = await BackgroundProtectionPrefs.load();
    if (bgPrefs.backgroundProtectionEnabled) {
      await ref
          .read(backgroundProtectionControllerProvider.notifier)
          .reconcileOnResume();
      return;
    }

    final prefs = await ProtectionPrefs.load();
    if (prefs.protectionEnabled) {
      final controller = ref.read(scanControllerProvider.notifier);
      if (ref.read(scanControllerProvider).status == ScanStatus.idle) {
        await controller.startProtection(persist: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

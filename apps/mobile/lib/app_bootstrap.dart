import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/protection_orchestrator_providers.dart';
import 'services/recent_risk_controller.dart';
import 'services/risk_notification_service.dart';
import 'services/scanner_provider.dart';
import 'services/widget_sync_service.dart';

/// Initialises widget sync and restores protection via the orchestrator.
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
      unawaited(
        ref
            .read(protectionOrchestratorProvider.notifier)
            .reconcileOnLaunchOrResume(),
      );
    }
  }

  Future<void> _init() async {
    final notifications = ref.read(riskNotificationServiceProvider);
    await notifications.init();
    await notifications.handleNotificationLaunch();
    ref.read(widgetSyncServiceProvider);
    await ref.read(scannerConfigInitProvider.future);
    await ref
        .read(protectionOrchestratorProvider.notifier)
        .reconcileOnLaunchOrResume();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

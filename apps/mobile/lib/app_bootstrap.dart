import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/scan/scan_state.dart';
import 'services/protection_prefs.dart';
import 'services/scanner_provider.dart';
import 'services/widget_sync_service.dart';

/// Initialises widget sync and restores protection if the user left it on.
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    ref.read(widgetSyncServiceProvider);
    await ref.read(scannerConfigInitProvider.future);

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

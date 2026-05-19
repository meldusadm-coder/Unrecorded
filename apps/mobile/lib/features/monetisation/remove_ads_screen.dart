import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/entitlement_service.dart';

/// Fixed tier labels — store handles local currency.
const _tierLabels = <String, String>{
  'remove_ads_1': '£1',
  'remove_ads_3': '£3',
  'remove_ads_5': '£5',
  'remove_ads_10': '£10',
};

class RemoveAdsScreen extends ConsumerStatefulWidget {
  const RemoveAdsScreen({super.key});

  @override
  ConsumerState<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends ConsumerState<RemoveAdsScreen> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final service = await ref.read(entitlementServiceProvider.future);
    final products = await service.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _purchase(ProductDetails product) async {
    setState(() => _message = null);
    final service = await ref.read(entitlementServiceProvider.future);
    final started = await service.purchase(product);
    if (!started && mounted) {
      setState(() => _message = 'Purchase could not be started.');
    }
  }

  Future<void> _restore() async {
    setState(() => _message = 'Restoring purchases…');
    final service = await ref.read(entitlementServiceProvider.future);
    await service.restorePurchases();
    if (mounted) {
      setState(() => _message = 'Restore requested. If you previously paid, ads will be removed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adsRemoved = ref.watch(adsRemovedProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(size: 26),
        ),
        title: const Text(AppCopy.removeAdsTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const HelperText(text: AppCopy.removeAdsBody),
            const SizedBox(height: 8),
            const HelperText(text: AppCopy.removeAdsFreeNote),
            if (adsRemoved) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Ads are removed on this device.')),
                    ],
                  ),
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_products.isEmpty)
              ...removeAdsProductIds.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: null,
                    child: Text(
                      '${_tierLabels[id] ?? id} (configure in store)',
                    ),
                  ),
                ),
              )
            else
              ..._products.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    onPressed: adsRemoved ? null : () => _purchase(p),
                    child: Text(_tierLabels[p.id] ?? p.price),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _restore,
              child: const Text(AppCopy.restorePurchase),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(AppCopy.maybeLater),
            ),
          ],
        ),
      ),
    );
  }
}

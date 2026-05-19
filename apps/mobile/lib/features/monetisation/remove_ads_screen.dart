import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../services/entitlement_service.dart';
import '../../services/remove_ads_pricing.dart';

class RemoveAdsScreen extends ConsumerStatefulWidget {
  const RemoveAdsScreen({super.key});

  @override
  ConsumerState<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends ConsumerState<RemoveAdsScreen> {
  final _amountController = TextEditingController(
    text: RemoveAdsPricing.defaultGbp.toStringAsFixed(2),
  );

  bool _loading = false;
  String? _message;
  ProductDetails? _previewProduct;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amountGbp => RemoveAdsPricing.parseGbp(_amountController.text);

  Future<void> _loadPreview() async {
    final amount = _amountGbp;
    if (amount == null) {
      setState(() {
        _previewProduct = null;
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final service = await ref.read(entitlementServiceProvider.future);
    final product = await service.loadProductForAmount(amount);

    if (!mounted) return;
    setState(() {
      _previewProduct = product;
      _loading = false;
      if (product == null) {
        _message = 'This amount is not set up in the app store yet. '
            'Create product ${RemoveAdsPricing.productIdForGbp(amount)} '
            'in Play Console / App Store Connect.';
      }
    });
  }

  Future<void> _purchase() async {
    final amount = _amountGbp;
    if (amount == null) {
      setState(() => _message = AppCopy.removeAdsInvalidAmount);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final service = await ref.read(entitlementServiceProvider.future);
    final product =
        _previewProduct ?? await service.loadProductForAmount(amount);

    if (!mounted) return;

    if (product == null) {
      setState(() {
        _loading = false;
        _message = 'Could not find a store product for '
            '${RemoveAdsPricing.formatGbp(amount)}. '
            'Check store configuration.';
      });
      return;
    }

    final started = await service.purchase(product);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!started) {
        _message = 'Purchase could not be started.';
      } else {
        _message = 'Complete the payment in the store dialog.';
      }
    });
  }

  Future<void> _restore() async {
    setState(() => _message = 'Restoring purchases…');
    final service = await ref.read(entitlementServiceProvider.future);
    await service.restorePurchases();
    if (mounted) {
      setState(() => _message = AppCopy.restorePurchaseHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final amount = _amountGbp;
    final storePrice = _previewProduct?.price;

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
            const SizedBox(height: 8),
            const HelperText(text: AppCopy.removeAdsAmountHint),
            if (adsRemoved) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Ads are removed on this device.'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              enabled: !adsRemoved,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: AppCopy.removeAdsAmountLabel,
                prefixText: '£ ',
                helperText:
                    '${RemoveAdsPricing.formatGbp(RemoveAdsPricing.minGbp)}–'
                    '${RemoveAdsPricing.formatGbp(RemoveAdsPricing.maxGbp)}',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Check store price',
                  onPressed: adsRemoved || _loading ? null : _loadPreview,
                ),
              ),
              onSubmitted: (_) => _loadPreview(),
            ),
            if (storePrice != null && amount != null) ...[
              const SizedBox(height: 8),
              Text(
                'Store price: $storePrice',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: adsRemoved || amount == null ? null : _purchase,
                child: Text(
                  adsRemoved
                      ? 'Ads already removed'
                      : amount == null
                          ? AppCopy.removeAdsAmountLabel
                          : 'Pay ${RemoveAdsPricing.formatGbp(amount)} to remove ads',
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

import 'package:flutter/material.dart';
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
  late int _tierIndex =
      RemoveAdsPricing.tierIndexForAmount(RemoveAdsPricing.defaultGbp);

  bool _loading = false;
  String? _message;
  ProductDetails? _previewProduct;

  double get _amountGbp => RemoveAdsPricing.amountForTier(_tierIndex);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  Future<void> _loadPreview() async {
    final amount = _amountGbp;

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
        _message = AppCopy.removeAdsAmountUnavailable(
            RemoveAdsPricing.formatGbp(amount));
      }
    });
  }

  Future<void> _purchase() async {
    final amount = _amountGbp;

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
        _message = AppCopy.removeAdsAmountUnavailable(
            RemoveAdsPricing.formatGbp(amount));
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

  void _onTierChanged(int index) {
    setState(() => _tierIndex = index);
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
                      UnrecordedIcon(
                        asset: UnrecordedIconAsset.protection,
                        size: 24,
                        color: theme.colorScheme.primary,
                      ),
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
            Text(
              AppCopy.removeAdsAmountLabel,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              RemoveAdsPricing.formatGbp(amount),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${RemoveAdsPricing.formatGbp(RemoveAdsPricing.minGbp)} – '
              '${RemoveAdsPricing.formatGbp(RemoveAdsPricing.maxGbp)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            Slider(
              key: const Key('remove_ads_amount_slider'),
              value: _tierIndex.toDouble(),
              min: 0,
              max: (RemoveAdsPricing.tierCount - 1).toDouble(),
              divisions: RemoveAdsPricing.tierCount - 1,
              label: RemoveAdsPricing.formatGbp(amount),
              onChanged:
                  adsRemoved ? null : (value) => _onTierChanged(value.round()),
              onChangeEnd: adsRemoved ? null : (_) => _loadPreview(),
            ),
            if (storePrice != null) ...[
              const SizedBox(height: 4),
              Text(
                'Store price: $storePrice',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
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
                onPressed:
                    adsRemoved || _previewProduct == null ? null : _purchase,
                child: Text(
                  adsRemoved
                      ? 'Ads already removed'
                      : _previewProduct == null
                          ? 'Store product unavailable'
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

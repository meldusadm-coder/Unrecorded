/// Pay-what-you-want remove-ads pricing (one store product per tier in pence).
class RemoveAdsPricing {
  RemoveAdsPricing._();

  static const double defaultGbp = 2.0;
  static const double minGbp = 0.25;
  static const double maxGbp = 20.0;
  static const double stepGbp = 0.25;

  static int get tierCount =>
      ((maxGbp - minGbp) / stepGbp).round() + 1; // 80 tiers

  /// Legacy fixed-tier IDs still honoured on restore.
  static const legacyProductIds = <String>{
    'remove_ads_1',
    'remove_ads_3',
    'remove_ads_5',
    'remove_ads_10',
  };

  /// GBP amount for slider tier [index] (0 = £0.25).
  static double amountForTier(int index) {
    assert(index >= 0 && index < tierCount);
    return minGbp + index * stepGbp;
  }

  /// Nearest tier index for [gbp], clamped to valid range.
  static int tierIndexForAmount(double gbp) {
    final clamped = gbp.clamp(minGbp, maxGbp);
    final index = ((clamped - minGbp) / stepGbp).round();
    return index.clamp(0, tierCount - 1);
  }

  static bool isSupportedAmount(double gbp) {
    final pence = (gbp * 100).round();
    if (pence < 25 || pence > 2000) return false;
    return pence % 25 == 0;
  }

  /// Store product ID for a GBP amount, e.g. £2.00 → `remove_ads_200`.
  static String productIdForGbp(double gbp) {
    final pence = (gbp * 100).round();
    return 'remove_ads_$pence';
  }

  static bool isRemoveAdsProductId(String id) {
    if (legacyProductIds.contains(id)) return true;
    if (!id.startsWith('remove_ads_')) return false;
    final suffix = id.substring('remove_ads_'.length);
    if (suffix.isEmpty) return false;
    final pence = int.tryParse(suffix);
    if (pence == null) return false;
    return pence >= 25 && pence <= 2000 && pence % 25 == 0;
  }

  /// Parses user input; returns null if invalid or not on the tier grid.
  static double? parseGbp(String input) {
    final trimmed = input.trim().replaceFirst(RegExp(r'^£\s*'), '');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null) return null;
    final rounded = double.parse(value.toStringAsFixed(2));
    if (!isSupportedAmount(rounded)) return null;
    return rounded;
  }

  static String formatGbp(double gbp) => '£${gbp.toStringAsFixed(2)}';
}

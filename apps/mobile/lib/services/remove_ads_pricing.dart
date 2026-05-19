/// Pay-what-you-want remove-ads pricing (store product per amount in pence).
class RemoveAdsPricing {
  RemoveAdsPricing._();

  static const double defaultGbp = 2.0;
  static const double minGbp = 0.50;
  static const double maxGbp = 100.0;

  /// Legacy fixed-tier IDs still honoured on restore.
  static const legacyProductIds = <String>{
    'remove_ads_1',
    'remove_ads_3',
    'remove_ads_5',
    'remove_ads_10',
  };

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
    return int.tryParse(suffix) != null;
  }

  /// Parses user input; returns null if invalid.
  static double? parseGbp(String input) {
    final trimmed = input.trim().replaceFirst(RegExp(r'^£\s*'), '');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null || value < minGbp || value > maxGbp) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  static String formatGbp(double gbp) => '£${gbp.toStringAsFixed(2)}';
}

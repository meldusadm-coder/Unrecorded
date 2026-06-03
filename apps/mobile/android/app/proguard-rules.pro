# Project ProGuard/R8 rules for release builds (Flutter applies this file automatically).
# Keeps reflection-heavy plugin surfaces safe under R8 minification.

# flutter_blue_plus — required for release BLE scanning
# https://pub.dev/packages/flutter_blue_plus
-keep class com.lib.flutter_blue_plus.** { *; }

# Google Mobile Ads Flutter plugin + AdMob SDK
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class com.google.android.gms.ads.** { *; }

# WebView (transitive dependency of google_mobile_ads)
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Play Billing / in_app_purchase Android implementation
-keep class io.flutter.plugins.inapppurchase.** { *; }

# Home screen widget bridge
-keep class es.antonborri.home_widget.** { *; }

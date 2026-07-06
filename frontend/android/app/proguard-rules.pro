# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# If you are using the GmsBarcodeScanning API, you may also need:
-keep class com.google.android.gms.internal.mlkit_code_scanner.** { *; }

# Mobile Scanner plugin rules
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

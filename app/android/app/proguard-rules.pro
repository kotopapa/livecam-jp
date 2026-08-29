# Flutter / Firebase / AdMob は各ライブラリが consumer rules を同梱している。
# YouTube IFrame 用 WebView の JS インターフェースを保持
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }

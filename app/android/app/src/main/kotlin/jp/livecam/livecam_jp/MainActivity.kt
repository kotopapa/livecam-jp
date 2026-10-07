package jp.livecam.livecam_jp

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "livecam/native_config"

    // ルート検索(Google Routes API)・地名検索(Google Places API (New))用:
    // 新しいAPIキーは発行せず、地図表示に使っているGoogle Mapsキー
    // (AndroidManifestのmeta-data com.google.android.geo.API_KEY)をDart側へ渡す。
    // キーはパッケージ名＋署名で制限されているため、REST呼び出し用に
    // パッケージ名と署名証明書のSHA-1もヘッダー用に返す（lib/data/native_config.dart）
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleMapsApiKey" -> result.success(googleMapsApiKey())
                    "getAppRestrictionHeaders" -> result.success(appRestrictionHeaders())
                    "isLowDataMode" -> result.success(isLowDataMode())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 端末のデータセーバーが有効か（通信節約モードの自動判定用）。
     * メーター制の回線につながっていて、かつ「バックグラウンドデータの制限」が
     * 有効（RESTRICT_BACKGROUND_STATUS_ENABLED）のときだけ true
     */
    private fun isLowDataMode(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.isActiveNetworkMetered &&
                cm.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
        } catch (e: Exception) {
            false
        }
    }

    private fun googleMapsApiKey(): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            info.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    private fun appRestrictionHeaders(): Map<String, String> {
        val sha1 = signingCertSha1()
        return if (sha1 == null) {
            mapOf("X-Android-Package" to packageName)
        } else {
            mapOf("X-Android-Package" to packageName, "X-Android-Cert" to sha1)
        }
    }

    /** 署名証明書のSHA-1（大文字16進・コロン無し）。取得できなければ null */
    private fun signingCertSha1(): String? {
        return try {
            val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNING_CERTIFICATES
                )
                info.signingInfo?.apkContentsSigners ?: return null
            } else {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                info.signatures ?: return null
            }
            if (signatures.isEmpty()) return null
            val digest = MessageDigest.getInstance("SHA-1").digest(signatures[0].toByteArray())
            digest.joinToString("") { String.format("%02X", it) }
        } catch (e: Exception) {
            null
        }
    }
}

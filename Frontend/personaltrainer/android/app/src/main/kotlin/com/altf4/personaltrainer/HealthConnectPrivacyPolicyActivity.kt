package com.altf4.personaltrainer

import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class HealthConnectPrivacyPolicyActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val webView = WebView(this)
        setContentView(webView)
        // Redirige a la política de privacidad real
        webView.loadUrl("https://tu-web.com/privacy-policy")
    }
}

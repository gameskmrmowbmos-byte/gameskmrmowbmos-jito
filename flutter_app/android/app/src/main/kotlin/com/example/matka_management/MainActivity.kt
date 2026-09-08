package com.example.matka_management

import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "matka_management/system_print"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method != "printHtml") {
					result.notImplemented()
					return@setMethodCallHandler
				}
				val html = call.argument<String>("html")
				if (html.isNullOrBlank()) {
					result.error("EMPTY_DOCUMENT", "Print document is empty", null)
					return@setMethodCallHandler
				}
				printHtml(html, result)
			}
	}

	private fun printHtml(html: String, result: MethodChannel.Result) {
		val webView = WebView(this)
		webView.settings.defaultFontSize = 11
		webView.webViewClient = object : WebViewClient() {
			override fun onPageFinished(view: WebView, url: String) {
				val printManager = getSystemService(PRINT_SERVICE) as PrintManager
				val adapter = view.createPrintDocumentAdapter("Receipt")
				val attributes = PrintAttributes.Builder()
					.setMediaSize(PrintAttributes.MediaSize("RECEIPT", "Receipt", 228, 864))
					.setMinMargins(PrintAttributes.Margins.NO_MARGINS)
					.build()
				printManager.print("Receipt", adapter, attributes)
				result.success(null)
			}
		}
		webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
	}
}


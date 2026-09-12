package com.example.matka_management

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.print.PrintAttributes
import android.print.PrintManager
import android.provider.MediaStore
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "matka_management/system_print"
	private val downloadsChannelName = "matka_management/downloads"

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
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannelName)
			.setMethodCallHandler { call, result ->
				if (call.method != "saveImageToGallery") {
					result.notImplemented()
					return@setMethodCallHandler
				}
				val bytes = call.argument<ByteArray>("bytes")
				val filename = call.argument<String>("filename")
				val mimeType = call.argument<String>("mimeType") ?: "image/png"
				if (bytes == null || bytes.isEmpty() || filename.isNullOrBlank()) {
					result.error("INVALID_IMAGE", "Image data or filename is missing", null)
					return@setMethodCallHandler
				}
				saveImageToGallery(bytes, filename, mimeType, result)
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

	private fun saveImageToGallery(
		bytes: ByteArray,
		filename: String,
		mimeType: String,
		result: MethodChannel.Result
	) {
		try {
			val resolver = contentResolver
			val values = ContentValues().apply {
				put(MediaStore.Images.Media.DISPLAY_NAME, filename)
				put(MediaStore.Images.Media.MIME_TYPE, mimeType)
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
					put(
						MediaStore.Images.Media.RELATIVE_PATH,
						"${Environment.DIRECTORY_PICTURES}/Matka Management"
					)
					put(MediaStore.Images.Media.IS_PENDING, 1)
				}
			}
			val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
			} else {
				MediaStore.Images.Media.EXTERNAL_CONTENT_URI
			}
			val uri = resolver.insert(collection, values)
			if (uri == null) {
				result.error("GALLERY_SAVE_FAILED", "Could not create gallery image", null)
				return
			}
			resolver.openOutputStream(uri)?.use { stream ->
				stream.write(bytes)
				stream.flush()
			} ?: run {
				result.error("GALLERY_SAVE_FAILED", "Could not open gallery image", null)
				return
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				val readyValues = ContentValues().apply {
					put(MediaStore.Images.Media.IS_PENDING, 0)
				}
				resolver.update(uri, readyValues, null, null)
			}
			result.success(uri.toString())
		} catch (error: Exception) {
			result.error("GALLERY_SAVE_FAILED", error.message, null)
		}
	}
}

package com.example.matka_management

import android.content.ContentValues
import android.media.MediaScannerConnection
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
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
	private val channelName = "matka_management/system_print"
	private val galleryChannelName = "matka_management/gallery"

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
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "androidSdkInt") {
					result.success(Build.VERSION.SDK_INT)
					return@setMethodCallHandler
				}
				if (call.method != "saveImageToGallery") {
					result.notImplemented()
					return@setMethodCallHandler
				}
				val bytes = call.argument<ByteArray>("bytes")
				val filename = call.argument<String>("filename") ?: "matka-record.png"
				val mimeType = call.argument<String>("mimeType") ?: "image/png"
				if (bytes == null || bytes.isEmpty()) {
					result.error("EMPTY_IMAGE", "Image file is empty", null)
					return@setMethodCallHandler
				}
				saveImageToGallery(bytes, filename, mimeType, result)
			}
	}

	private fun saveImageToGallery(
		bytes: ByteArray,
		filename: String,
		mimeType: String,
		result: MethodChannel.Result
	) {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
			saveLegacyImageToGallery(bytes, filename, mimeType, result)
			return
		}
		val values = ContentValues().apply {
			put(MediaStore.Images.Media.DISPLAY_NAME, filename)
			put(MediaStore.Images.Media.MIME_TYPE, mimeType)
			put(
				MediaStore.Images.Media.RELATIVE_PATH,
				"${Environment.DIRECTORY_PICTURES}/Matka Management"
			)
			put(MediaStore.Images.Media.IS_PENDING, 1)
		}
		val resolver = contentResolver
		val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
		if (uri == null) {
			result.error("SAVE_FAILED", "Unable to create gallery image", null)
			return
		}
		try {
			resolver.openOutputStream(uri)?.use { output ->
				output.write(bytes)
			} ?: throw IllegalStateException("Unable to open image output stream")
			values.clear()
			values.put(MediaStore.Images.Media.IS_PENDING, 0)
			resolver.update(uri, values, null, null)
			result.success(uri.toString())
		} catch (error: Exception) {
			resolver.delete(uri, null, null)
			result.error("SAVE_FAILED", error.message ?: "Unable to save image", null)
		}
	}

	private fun saveLegacyImageToGallery(
		bytes: ByteArray,
		filename: String,
		mimeType: String,
		result: MethodChannel.Result
	) {
		try {
			val picturesDir = Environment.getExternalStoragePublicDirectory(
				Environment.DIRECTORY_PICTURES
			)
			val appDir = File(picturesDir, "Matka Management")
			if (!appDir.exists() && !appDir.mkdirs()) {
				throw IllegalStateException("Unable to create gallery folder")
			}
			val file = File(appDir, filename)
			FileOutputStream(file).use { output -> output.write(bytes) }
			MediaScannerConnection.scanFile(
				this,
				arrayOf(file.absolutePath),
				arrayOf(mimeType),
				null
			)
			result.success(file.absolutePath)
		} catch (error: Exception) {
			result.error("SAVE_FAILED", error.message ?: "Unable to save image", null)
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


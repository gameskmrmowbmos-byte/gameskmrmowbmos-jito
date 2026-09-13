import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const _galleryChannel = MethodChannel('matka_management/gallery');

Future<String> saveDownloadedFile(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  if (mimeType.startsWith('image/')) {
    try {
      if (Platform.isAndroid) {
        final sdkInt = await _galleryChannel.invokeMethod<int>('androidSdkInt');
        if (sdkInt != null && sdkInt <= 28) {
          final permission = await Permission.storage.request();
          if (!permission.isGranted) {
            throw StateError('Storage permission denied. PNG was not saved.');
          }
        }
      }
      final savedUri = await _galleryChannel.invokeMethod<String>(
        'saveImageToGallery',
        {
          'bytes': bytes,
          'filename': filename,
          'mimeType': mimeType,
        },
      );
      if (savedUri != null && savedUri.isNotEmpty) return savedUri;
    } on PlatformException catch (error) {
      if (Platform.isAndroid) {
        final message = error.message?.trim();
        throw StateError(
          message?.isNotEmpty == true
              ? 'Gallery save failed: $message'
              : 'Gallery save failed.',
        );
      }
      // Fall back to app documents if the platform gallery path is unavailable.
    } on MissingPluginException {
      if (Platform.isAndroid) {
        throw StateError('Gallery save is not available on this Android build.');
      }
      // Desktop builds do not register the Android gallery channel.
    }
  }

  return _saveToAppDocuments(bytes, filename);
}

Future<String> _saveToAppDocuments(Uint8List bytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloadsChannel = MethodChannel('matka_management/downloads');

Future<String> saveDownloadedFile(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  if (Platform.isAndroid && mimeType.startsWith('image/')) {
    try {
      final savedUri = await _downloadsChannel.invokeMethod<String>(
        'saveImageToGallery',
        {
          'bytes': bytes,
          'filename': filename,
          'mimeType': mimeType,
        },
      );
      if (savedUri != null && savedUri.isNotEmpty) return savedUri;
    } on PlatformException {
      // Fall back to app documents if the platform gallery save fails.
    }
  }

  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

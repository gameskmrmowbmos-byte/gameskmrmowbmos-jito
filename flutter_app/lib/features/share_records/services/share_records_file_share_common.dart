import 'dart:typed_data';

class SharePngFile {
  const SharePngFile({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

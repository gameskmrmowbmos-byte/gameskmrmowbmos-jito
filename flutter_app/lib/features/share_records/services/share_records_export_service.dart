import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:matka_management/core/utils/download_service.dart';
import 'package:matka_management/features/share_records/services/share_records_file_share.dart';

class ShareRecordsExportService {
  ShareRecordsExportService._();

  static Future<Uint8List?> capturePngFromKey(GlobalKey key,
      {double pixelRatio = 3.0}) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;
      await WidgetsBinding.instance.endOfFrame;
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing PNG: $e');
      return null;
    }
  }

  static String sanitizeFilename(String text) {
    return text.replaceAll(RegExp(r'[^\w\.-]+'), '-').toLowerCase();
  }

  static Future<String> savePngFile({
    required Uint8List pngBytes,
    required String filename,
  }) async {
    final sanitized = sanitizeFilename(filename);
    return saveDownloadedFile(pngBytes, sanitized, 'image/png');
  }

  static Future<String> savePdfFile({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    final sanitized = sanitizeFilename(filename);
    return saveDownloadedFile(pdfBytes, sanitized, 'application/pdf');
  }

  static Future<Uint8List> buildPdfFromPngPages(
      List<Uint8List> pngPages) async {
    if (pngPages.isEmpty) {
      throw ArgumentError('At least one PNG page is required');
    }

    final images = <_PdfImage>[];
    for (final pngBytes in pngPages) {
      images.add(await _decodePngForPdf(pngBytes));
    }
    return _SimplePdfBuilder(images).build();
  }

  static Future<void> shareSinglePage({
    required Uint8List pngBytes,
    required String filename,
    required String title,
  }) async {
    final sanitized = sanitizeFilename(filename);
    await sharePngFiles(
      files: [
        SharePngFile(
          bytes: pngBytes,
          filename: sanitized,
        ),
      ],
      title: title,
    );
  }

  static Future<void> shareAllPages({
    required List<Uint8List> pngPages,
    required String baseFilename,
    required String title,
  }) async {
    final files = <SharePngFile>[];

    for (int i = 0; i < pngPages.length; i++) {
      final pageNum = (i + 1).toString().padLeft(2, '0');
      final name = '${sanitizeFilename(baseFilename)}-page-$pageNum.png';
      files.add(SharePngFile(bytes: pngPages[i], filename: name));
    }

    await sharePngFiles(files: files, title: title);
  }

  static Future<_PdfImage> _decodePngForPdf(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      throw StateError('Failed to decode PNG for PDF export');
    }

    final rgba = byteData.buffer.asUint8List();
    final rgb = Uint8List(image.width * image.height * 3);
    for (var src = 0, dst = 0; src < rgba.length; src += 4, dst += 3) {
      final alpha = rgba[src + 3] / 255;
      rgb[dst] = (rgba[src] * alpha + 255 * (1 - alpha)).round();
      rgb[dst + 1] = (rgba[src + 1] * alpha + 255 * (1 - alpha)).round();
      rgb[dst + 2] = (rgba[src + 2] * alpha + 255 * (1 - alpha)).round();
    }

    final pdfImage = _PdfImage(
      width: image.width,
      height: image.height,
      rgbBytes: rgb,
    );
    image.dispose();
    return pdfImage;
  }
}

class _PdfImage {
  const _PdfImage({
    required this.width,
    required this.height,
    required this.rgbBytes,
  });

  final int width;
  final int height;
  final Uint8List rgbBytes;
}

class _SimplePdfBuilder {
  _SimplePdfBuilder(this.images);

  static const double _pageWidth = 842;
  static const double _pageHeight = 595;

  final List<_PdfImage> images;

  Uint8List build() {
    final objectCount = 2 + images.length * 3;
    final objects = List<Uint8List?>.filled(objectCount + 1, null);

    final pageIds = <int>[];
    for (var index = 0; index < images.length; index++) {
      final pageId = 3 + index * 3;
      final contentId = pageId + 1;
      final imageId = pageId + 2;
      final imageName = 'Im${index + 1}';

      pageIds.add(pageId);
      objects[pageId] = _ascii(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $_pageWidth $_pageHeight] '
        '/Resources << /XObject << /$imageName $imageId 0 R >> >> '
        '/Contents $contentId 0 R >>',
      );

      final content =
          _ascii('q\n$_pageWidth 0 0 $_pageHeight 0 0 cm\n/$imageName Do\nQ\n');
      objects[contentId] = _streamObject(content);

      final image = images[index];
      objects[imageId] = _imageObject(image);
    }

    objects[1] = _ascii('<< /Type /Catalog /Pages 2 0 R >>');
    objects[2] = _ascii(
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
      '/Count ${images.length} >>',
    );

    return _writePdf(objects);
  }

  static Uint8List _writePdf(List<Uint8List?> objects) {
    final builder = BytesBuilder();
    final offsets = List<int>.filled(objects.length, 0);

    void addAscii(String value) => builder.add(_ascii(value));

    addAscii('%PDF-1.4\n');
    for (var id = 1; id < objects.length; id++) {
      final object = objects[id]!;
      offsets[id] = builder.length;
      addAscii('$id 0 obj\n');
      builder.add(object);
      addAscii('\nendobj\n');
    }

    final xrefOffset = builder.length;
    addAscii('xref\n0 ${objects.length}\n');
    addAscii('0000000000 65535 f \n');
    for (var id = 1; id < objects.length; id++) {
      addAscii('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
    }
    addAscii(
      'trailer\n<< /Size ${objects.length} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n',
    );

    return builder.toBytes();
  }

  static Uint8List _imageObject(_PdfImage image) {
    final builder = BytesBuilder();
    builder.add(_ascii(
      '<< /Type /XObject /Subtype /Image /Width ${image.width} /Height ${image.height} '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 '
      '/Length ${image.rgbBytes.length} >>\nstream\n',
    ));
    builder.add(image.rgbBytes);
    builder.add(_ascii('\nendstream'));
    return builder.toBytes();
  }

  static Uint8List _streamObject(Uint8List bytes) {
    final builder = BytesBuilder();
    builder.add(_ascii('<< /Length ${bytes.length} >>\nstream\n'));
    builder.add(bytes);
    builder.add(_ascii('endstream'));
    return builder.toBytes();
  }

  static Uint8List _ascii(String value) =>
      Uint8List.fromList(latin1.encode(value));
}

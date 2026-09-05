import 'dart:io';

import 'package:matka_management/features/share_records/services/share_records_file_share_common.dart';
import 'package:share_plus/share_plus.dart';

Future<void> sharePngFiles({
  required List<SharePngFile> files,
  required String title,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('matka-share-');
  final xfiles = <XFile>[];
  final filenames = <String>[];

  for (final item in files) {
    final filePath = '${tempDir.path}${Platform.pathSeparator}${item.filename}';
    final file = File(filePath);
    await file.writeAsBytes(item.bytes, flush: true);
    xfiles.add(XFile(filePath, mimeType: 'image/png', name: item.filename));
    filenames.add(item.filename);
  }

  await Share.shareXFiles(
    xfiles,
    text: title,
    fileNameOverrides: filenames,
  );
}

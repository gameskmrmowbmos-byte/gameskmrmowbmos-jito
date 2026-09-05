import 'package:matka_management/features/share_records/services/share_records_file_share_common.dart';
import 'package:share_plus/share_plus.dart';

Future<void> sharePngFiles({
  required List<SharePngFile> files,
  required String title,
}) async {
  await Share.shareXFiles(
    [
      for (final item in files)
        XFile.fromData(
          item.bytes,
          mimeType: 'image/png',
          name: item.filename,
        ),
    ],
    text: title,
    fileNameOverrides: [for (final item in files) item.filename],
  );
}

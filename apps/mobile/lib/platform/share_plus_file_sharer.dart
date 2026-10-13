import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';
import 'package:share_plus/share_plus.dart';

/// Android share sheet (Drive, e-mail, Files, ...) via share_plus.
class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> share(List<ExportedFile> files, {required String subject}) =>
      SharePlus.instance.share(
        ShareParams(
          subject: subject,
          files: [
            for (final f in files)
              XFile(f.path, name: f.name, mimeType: f.mimeType),
          ],
        ),
      );
}

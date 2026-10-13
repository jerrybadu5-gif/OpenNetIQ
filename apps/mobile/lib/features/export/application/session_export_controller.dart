import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/export/file_session_exporter.dart';
import 'package:opennetiq_mobile/data/local/drift_export_store.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/platform/share_plus_file_sharer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final sessionExporterProvider = Provider<SessionExporter>(
  (ref) => FileSessionExporter(
    load: DriftExportStore(ref.watch(appDatabaseProvider)).load,
    directory: () async =>
        Directory(p.join((await getTemporaryDirectory()).path, 'exports')),
  ),
);

final fileSharerProvider = Provider<FileSharer>(
  (ref) => const SharePlusFileSharer(),
);

class SessionExportState {
  const SessionExportState({
    this.busy = false,
    this.files = const [],
    this.error,
  });

  final bool busy;

  /// Files of the last successful export.
  final List<ExportedFile> files;
  final String? error;

  /// One-line outcome for a snack bar, null while idle.
  String? get message {
    if (busy) return null;
    if (error != null) return error;
    if (files.isEmpty) return null;
    return 'Exported ${files.map((f) => f.name).join(', ')}';
  }
}

/// Builds the files of one session and opens the share sheet (#23).
class SessionExportController extends Notifier<SessionExportState> {
  @override
  SessionExportState build() => const SessionExportState();

  Future<void> export(
    String sessionId,
    Set<ExportFormat> formats, {
    required String subject,
  }) async {
    if (state.busy || formats.isEmpty) return;
    state = const SessionExportState(busy: true);
    final List<ExportedFile> files;
    try {
      files = await ref
          .read(sessionExporterProvider)
          .export(sessionId, formats);
    } on Object catch (e) {
      state = SessionExportState(error: 'Export failed: $e');
      return;
    }
    try {
      await ref.read(fileSharerProvider).share(files, subject: subject);
    } on Object catch (e) {
      state = SessionExportState(files: files, error: 'Could not share: $e');
      return;
    }
    state = SessionExportState(files: files);
  }
}

final sessionExportControllerProvider =
    NotifierProvider<SessionExportController, SessionExportState>(
      SessionExportController.new,
    );

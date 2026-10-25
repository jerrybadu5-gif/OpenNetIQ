import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';
import 'package:opennetiq_mobile/features/export/application/session_export_controller.dart';

/// Export choices for one session (#23). Returns the chosen formats.
class ExportSheet extends StatelessWidget {
  const ExportSheet({super.key});

  /// Lets the user pick formats, then exports with the caller's [ref] and
  /// reports the outcome in a snack bar of the calling screen.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String sessionId,
    required String sessionName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final formats = await showModalBottomSheet<Set<ExportFormat>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ExportSheet(),
    );
    if (formats == null || formats.isEmpty) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing export...')),
    );
    await ref
        .read(sessionExportControllerProvider.notifier)
        .export(sessionId, formats, subject: 'OpenNetIQ export: $sessionName');
    final message = ref.read(sessionExportControllerProvider).message;
    messenger.hideCurrentSnackBar();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    void pick(Set<ExportFormat> formats) => Navigator.of(context).pop(formats);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Export session')),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              subtitle: const Text(
                'One row per sample (Excel, QGIS), plus a tests file',
              ),
              onTap: () => pick({ExportFormat.csv}),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('GeoJSON'),
              subtitle: const Text('Track, samples and tests (QGIS, web maps)'),
              onTap: () => pick({ExportFormat.geojson}),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('KML'),
              subtitle: const Text(
                'Google Earth: coloured track, samples, estimated sites',
              ),
              onTap: () => pick({ExportFormat.kml}),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('All formats'),
              subtitle: const Text('CSV, GeoJSON and KML'),
              onTap: () => pick({
                ExportFormat.csv,
                ExportFormat.geojson,
                ExportFormat.kml,
              }),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Files contain locations and network data of this session. '
                'Share them only with people who should see it.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

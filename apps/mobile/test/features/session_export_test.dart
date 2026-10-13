import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';
import 'package:opennetiq_mobile/features/export/application/session_export_controller.dart';
import 'package:opennetiq_mobile/features/export/presentation/export_sheet.dart';

class FakeExporter implements SessionExporter {
  final calls = <(String, Set<ExportFormat>)>[];
  Object? error;

  @override
  Future<List<ExportedFile>> export(
    String sessionId,
    Set<ExportFormat> formats,
  ) async {
    calls.add((sessionId, formats));
    final e = error;
    if (e != null) throw e;
    return [
      for (final f in formats)
        ExportedFile(
          path: '/tmp/x.${f.name}',
          name: 'x.${f.name}',
          mimeType: 'text/plain',
          rows: 1,
        ),
    ];
  }
}

class FakeSharer implements FileSharer {
  final shared = <List<ExportedFile>>[];
  final subjects = <String>[];
  Object? error;

  @override
  Future<void> share(
    List<ExportedFile> files, {
    required String subject,
  }) async {
    final e = error;
    if (e != null) throw e;
    shared.add(files);
    subjects.add(subject);
  }
}

void main() {
  late FakeExporter exporter;
  late FakeSharer sharer;

  setUp(() {
    exporter = FakeExporter();
    sharer = FakeSharer();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sessionExporterProvider.overrideWithValue(exporter),
        fileSharerProvider.overrideWithValue(sharer),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('controller', () {
    test('exports then shares', () async {
      final c = container();
      await c.read(sessionExportControllerProvider.notifier).export('s', {
        ExportFormat.csv,
      }, subject: 'subj');
      expect(exporter.calls.single.$1, 's');
      expect(sharer.shared.single.single.name, 'x.csv');
      expect(sharer.subjects, ['subj']);
      expect(c.read(sessionExportControllerProvider).message, 'Exported x.csv');
    });

    test('export errors are reported, nothing shared', () async {
      exporter.error = StateError('gone');
      final c = container();
      await c.read(sessionExportControllerProvider.notifier).export('s', {
        ExportFormat.csv,
      }, subject: 'subj');
      expect(sharer.shared, isEmpty);
      expect(
        c.read(sessionExportControllerProvider).message,
        startsWith('Export failed'),
      );
    });

    test('share errors keep the files', () async {
      sharer.error = Exception('no app');
      final c = container();
      await c.read(sessionExportControllerProvider.notifier).export('s', {
        ExportFormat.geojson,
      }, subject: 'subj');
      final state = c.read(sessionExportControllerProvider);
      expect(state.files, hasLength(1));
      expect(state.message, startsWith('Could not share'));
    });

    test('no formats: nothing happens', () async {
      final c = container();
      await c
          .read(sessionExportControllerProvider.notifier)
          .export('s', {}, subject: 'subj');
      expect(exporter.calls, isEmpty);
      expect(c.read(sessionExportControllerProvider).message, isNull);
    });
  });

  testWidgets('sheet exports both formats and reports', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionExporterProvider.overrideWithValue(exporter),
          fileSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ExportSheet.show(
                  context,
                  ref,
                  sessionId: 'sess-1',
                  sessionName: 'Route 1',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Export session'), findsOneWidget);
    await tester.tap(find.text('CSV + GeoJSON'));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$2, {ExportFormat.csv, ExportFormat.geojson});
    expect(sharer.subjects.single, 'OpenNetIQ export: Route 1');
    expect(find.text('Exported x.csv, x.geojson'), findsOneWidget);
  });

  testWidgets('dismissing the sheet exports nothing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionExporterProvider.overrideWithValue(exporter),
          fileSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ExportSheet.show(
                  context,
                  ref,
                  sessionId: 's',
                  sessionName: 'n',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(exporter.calls, isEmpty);
  });
}

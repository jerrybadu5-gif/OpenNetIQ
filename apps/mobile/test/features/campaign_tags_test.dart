import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/domain/entities/campaign_tags.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/campaign/application/campaign_controller.dart';
import 'package:opennetiq_mobile/features/campaign/presentation/campaign_card.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/script_fixtures.dart';

class BrokenSettings extends MemorySettings {
  @override
  Future<String?> getSetting(String key) async => throw StateError('db');
}

void main() {
  test('tags normalise, summarise and round-trip JSON', () {
    const raw = CampaignTags(
      region: ' Southern ',
      areaClass: AreaClass.semiUrban,
      location: '  ',
    );
    final t = raw.normalised();
    expect(t.region, 'Southern');
    expect(t.location, isNull);
    expect(t.summary, 'Southern · Semi-urban');
    expect(CampaignTags.fromJson(t.toJson()), t);
    expect(t.toJson(), {
      'version': 1,
      'region': 'Southern',
      'area_class': 'semi_urban',
    });
    expect(CampaignTags.none.isEmpty, isTrue);
    expect(CampaignTags.none.summary, '');
    expect(AreaClass.fromWire('x'), isNull);
    expect(t.hashCode, CampaignTags.fromJson(t.toJson()).hashCode);
    expect(pngRegions, hasLength(4));
  });

  test('controller persists; broken settings never block sessions', () async {
    final settings = MemorySettings();
    final c = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(c.dispose);
    expect(await c.read(campaignTagsProvider.future), CampaignTags.none);
    await c
        .read(campaignTagsProvider.notifier)
        .save(const CampaignTags(region: 'Momase ', location: 'Lae'));
    expect(settings.values[campaignTagsKey], contains('"region":"Momase"'));
    final again = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(again.dispose);
    expect((await again.read(campaignTagsProvider.future)).location, 'Lae');

    settings.values[campaignTagsKey] = '{bad';
    final bad = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(bad.dispose);
    expect(await bad.read(campaignTagsProvider.future), CampaignTags.none);

    final broken = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(BrokenSettings()),
      ],
    );
    addTearDown(broken.dispose);
    final probe = Provider((ref) => currentCampaignTags(ref));
    expect(await broken.read(probe), CampaignTags.none);
  });

  test('sessions store and read back their tags', () async {
    final AppDatabase db = memoryDatabase();
    addTearDown(db.close);
    final store = DriftMeasurementStore(db);
    await db.customStatement(
      "INSERT INTO devices VALUES ('d1','m','x','14',34,NULL,'1.0.0',"
      "'2026-10-08T00:00:00.000Z','2026-10-08T00:00:00.000Z')",
    );
    final s = await store.createSession(
      deviceId: 'd1',
      name: 'n',
      type: SessionType.stationary,
      samplingIntervalMs: 1000,
      tags: const CampaignTags(
        region: 'Islands',
        areaClass: AreaClass.rural,
        location: 'Kokopo',
      ),
    );
    expect(s.tags.region, 'Islands');
    expect(s.tags.areaClass, AreaClass.rural);
    expect(s.tags.location, 'Kokopo');
  });

  testWidgets('card edits, picks suggestions and clears', (tester) async {
    final settings = MemorySettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
        child: const MaterialApp(home: Scaffold(body: CampaignTagsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Measurement location not set'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highlands'));
    await tester.tap(find.text('Urban'));
    await tester.enterText(find.byType(TextField).last, 'Mt Hagen');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Mt Hagen · Highlands · Urban'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urban'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mt Hagen · Highlands · Urban'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Measurement location not set'), findsOneWidget);
  });
}

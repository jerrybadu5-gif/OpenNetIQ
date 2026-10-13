import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_latency_store.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/latency_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftLatencyStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftLatencyStore(db, now: () => DateTime.utc(2026, 10, 9, 2));
  });
  tearDown(() => db.close());

  LatencyRecord record(String id, LatencyResult result, {int day = 9}) =>
      LatencyRecord(
        id: id,
        timestamp: DateTime.utc(2026, 10, day, 1),
        methodologyVersion: '1.0.0',
        result: result,
      );

  test('one row per protocol with raw RTTs as JSON', () async {
    await store.saveLatencyTests([
      record('a', latencyResult(protocol: LatencyProtocol.icmp)),
      record('b', latencyResult()),
      record(
        'c',
        latencyResult(
          protocol: LatencyProtocol.dns,
          status: TestStatus.failed,
          medianMs: null,
          lossPct: 100,
        ),
      ),
    ]);

    final rows = await db.select(db.latencyTests).get();
    expect(rows, hasLength(3));
    final tcp = rows.singleWhere((r) => r.protocol == 'tcp');
    expect(tcp.rawRttsMs, '[20.0,30.0,null,25.0,40.0]');
    expect(tcp.p95Ms, 40);
    expect(tcp.status, 'ok');
    expect(tcp.createdAt, '2026-10-09T02:00:00.000Z');
    expect(tcp.timestamp, '2026-10-09T01:00:00.000Z');

    final records = await store.watchLatencyTests().first;
    expect(records.map((r) => r.result.protocol), [
      LatencyProtocol.dns,
      LatencyProtocol.icmp,
      LatencyProtocol.tcp,
    ]);
    final dns = records.first.result;
    expect(dns.status, TestStatus.failed);
    expect(dns.medianMs, isNull);
    expect(records.last.result.rawRttsMs, [20.0, 30.0, null, 25.0, 40.0]);
    expect(records.last.result.jitterMs, 12.6);
  });

  test('newest first and limited', () async {
    await store.saveLatencyTests([record('old', latencyResult(), day: 1)]);
    await store.saveLatencyTests([record('new', latencyResult(), day: 5)]);
    final records = await store.watchLatencyTests(limit: 1).first;
    expect(records.single.id, 'new');
  });

  test('a failing row rolls back the whole run', () async {
    await expectLater(
      store.saveLatencyTests([
        record('dup', latencyResult()),
        record('dup', latencyResult(protocol: LatencyProtocol.icmp)),
      ]),
      throwsA(anything),
    );
    expect(await db.select(db.latencyTests).get(), isEmpty);
  });
}

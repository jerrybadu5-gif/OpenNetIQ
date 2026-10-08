import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/services/sample_gaps.dart';
import 'package:opennetiq_mobile/domain/services/session_stats.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

/// Everything the session detail screen shows, loaded once.
class SessionDetail {
  const SessionDetail({
    required this.session,
    required this.points,
    required this.stats,
    required this.gaps,
  });

  final MeasurementSession session;
  final List<SamplePoint> points;
  final SessionStats stats;

  /// Post-hoc gap analysis. Pause times are not stored in schema v1, so a
  /// pause counts as a gap here (the live report at Stop excludes them).
  final GapReport gaps;
}

/// Null when the session does not exist (e.g. just deleted).
final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetail?, String>((ref, sessionId) async {
      final session = await ref
          .watch(sessionRepositoryProvider)
          .getSession(sessionId);
      if (session == null) return null;
      final points = await ref
          .watch(sampleRepositoryProvider)
          .loadSamplePoints(sessionId);
      return SessionDetail(
        session: session,
        points: points,
        stats: SessionStats.of(points),
        gaps: SampleGaps.analyse([
          for (final p in points) p.timestamp,
        ], Duration(milliseconds: session.samplingIntervalMs)),
      );
    });

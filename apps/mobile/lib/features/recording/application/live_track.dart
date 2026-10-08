import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';

/// Points of the session being recorded, appended per stored sample (kept
/// in memory so the live map never re-reads the database).
class LiveTrack extends Notifier<List<SamplePoint>> {
  @override
  List<SamplePoint> build() => const [];

  void reset() => state = const [];

  void add(SamplePoint point) => state = [...state, point];
}

final liveTrackProvider = NotifierProvider<LiveTrack, List<SamplePoint>>(
  LiveTrack.new,
);

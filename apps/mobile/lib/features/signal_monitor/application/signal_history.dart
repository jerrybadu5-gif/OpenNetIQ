import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// One point of the level trend. [levelDbm] is null when unavailable.
class SignalPoint {
  const SignalPoint({required this.time, this.levelDbm, this.rat});

  factory SignalPoint.fromSnapshot(RadioSnapshot snapshot) {
    final cell = snapshot.primaryCell;
    return SignalPoint(
      time: snapshot.timestamp,
      levelDbm: cell?.levelDbm,
      rat: cell?.rat,
    );
  }

  final DateTime time;
  final double? levelDbm;
  final Rat? rat;
}

/// Default window: 60 samples = 1 minute at the 1 s methodology interval.
const int signalHistoryCapacity = 60;

/// Appends [point], keeping at most [capacity] most recent points.
List<SignalPoint> appendPoint(
  List<SignalPoint> history,
  SignalPoint point, {
  int capacity = signalHistoryCapacity,
}) {
  final next = [...history, point];
  final overflow = next.length - capacity;
  return List.unmodifiable(overflow > 0 ? next.sublist(overflow) : next);
}

import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

/// Colour per quality class. Always shown together with the text label,
/// never as the only carrier of meaning (accessibility).
Color signalQualityColor(SignalQuality quality) => switch (quality) {
  SignalQuality.excellent => const Color(0xFF1B8A3A),
  SignalQuality.good => const Color(0xFF5B9E1F),
  SignalQuality.fair => const Color(0xFFC98A00),
  SignalQuality.poor => const Color(0xFFD9620B),
  SignalQuality.noService => const Color(0xFFC62828),
};

String formatDb(double? value, String unit) =>
    value == null ? '-' : '${value.toStringAsFixed(0)} $unit';

String formatInt(int? value) => value == null ? '-' : '$value';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

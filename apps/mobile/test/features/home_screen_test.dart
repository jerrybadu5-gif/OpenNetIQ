import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/core/flavor.dart';

void main() {
  for (final flavor in Flavor.values) {
    testWidgets('app shows ${flavor.name} title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flavorProvider.overrideWithValue(flavor)],
          child: const OpenNetIqApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(flavor.label), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }
}

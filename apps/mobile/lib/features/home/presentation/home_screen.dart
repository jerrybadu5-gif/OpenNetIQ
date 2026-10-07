import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/flavor.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    return Scaffold(
      appBar: AppBar(title: Text(flavor.label)),
      body: const Center(child: Text('Measurement features arrive in M1.')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/flavor.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    return Scaffold(
      appBar: AppBar(title: Text(flavor.label)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.signal_cellular_alt),
            title: const Text('Signal monitor'),
            subtitle: const Text(
              'Live serving and neighbour cells, 2G to 5G NSA/SA',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.signal),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.speed),
            title: Text('Speed & latency tests'),
            subtitle: Text('Coming in M1'),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.route),
            title: Text('Drive test'),
            subtitle: Text('Coming in M1'),
          ),
        ],
      ),
    );
  }
}

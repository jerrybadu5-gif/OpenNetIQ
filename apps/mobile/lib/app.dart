import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/flavor.dart';
import 'package:opennetiq_mobile/core/theme/app_theme.dart';
import 'package:opennetiq_mobile/features/drive_test/presentation/drive_test_screen.dart';
import 'package:opennetiq_mobile/features/home/presentation/home_screen.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/session_detail_screen.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/sessions_screen.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'signal',
            builder: (context, state) => const SignalMonitorScreen(),
          ),
          GoRoute(
            path: 'drive',
            builder: (context, state) => const DriveTestScreen(),
          ),
          GoRoute(
            path: 'sessions',
            builder: (context, state) => const SessionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    SessionDetailScreen(sessionId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);

class OpenNetIqApp extends ConsumerWidget {
  const OpenNetIqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: ref.watch(flavorProvider).label,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

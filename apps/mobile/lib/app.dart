import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/flavor.dart';
import 'package:opennetiq_mobile/core/theme/app_theme.dart';
import 'package:opennetiq_mobile/features/cells/presentation/cell_scan_screen.dart';
import 'package:opennetiq_mobile/features/drive_test/presentation/drive_test_screen.dart';
import 'package:opennetiq_mobile/features/latency_test/presentation/latency_test_screen.dart';
import 'package:opennetiq_mobile/features/home/presentation/home_screen.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/privacy/presentation/consent_screen.dart';
import 'package:opennetiq_mobile/features/privacy/presentation/privacy_screen.dart';
import 'package:opennetiq_mobile/features/qoe/presentation/qoe_test_screen.dart';
import 'package:opennetiq_mobile/features/scripts/presentation/script_editor_screen.dart';
import 'package:opennetiq_mobile/features/scripts/presentation/scripts_screen.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/session_detail_screen.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/sessions_screen.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';
import 'package:opennetiq_mobile/features/speed_test/presentation/speed_test_screen.dart';
import 'package:opennetiq_mobile/features/voice_sms/presentation/voice_sms_screen.dart';

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
            path: 'latency',
            builder: (context, state) => const LatencyTestScreen(),
          ),
          GoRoute(
            path: 'qoe',
            builder: (context, state) => const QoeTestScreen(),
          ),
          GoRoute(
            path: 'voice-sms',
            builder: (context, state) => const VoiceSmsScreen(),
          ),
          GoRoute(
            path: 'speed',
            builder: (context, state) => const SpeedTestScreen(),
          ),
          GoRoute(
            path: 'scripts',
            builder: (context, state) => const ScriptsScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => ScriptEditorScreen(
                  scriptId: state.uri.queryParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'cells',
            builder: (context, state) => const CellScanScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyScreen(),
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
                routes: [
                  GoRoute(
                    path: 'cells',
                    builder: (context, state) =>
                        CellScanScreen(sessionId: state.pathParameters['id']),
                  ),
                ],
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
    final title = ref.watch(flavorProvider).label;
    final consent = ref.watch(consentProvider);
    // Consent gate (#24): nothing else is shown, and nothing is measured,
    // until the user answered for the current policy version. If the
    // ledger cannot be read the app opens with measurement off.
    final Widget? gate = switch (consent.value) {
      null when consent.isLoading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      final status? when !status.decided => const ConsentScreen(),
      _ => null,
    };
    if (gate != null) {
      return MaterialApp(
        title: title,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: gate,
      );
    }
    return MaterialApp.router(
      title: title,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

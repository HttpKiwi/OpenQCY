import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/device/device_screen.dart';
import '../features/device/eq_editor_screen.dart';
import '../features/device/key_function_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ScanScreen(),
          transitionsBuilder: (context, animation, secondary, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondary,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/device',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DeviceScreen(),
          transitionsBuilder: (context, animation, secondary, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondary,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        ),
        routes: [
          GoRoute(
            path: 'keys',
            builder: (context, state) => const KeyFunctionScreen(),
          ),
          GoRoute(
            path: 'eq',
            builder: (context, state) => const EqEditorScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class MeloControlApp extends ConsumerWidget {
  const MeloControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Melo Control',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services/analytics_service.dart';
import '../ui/dashboard/screens/dashboard_screen.dart';
import '../ui/home_map/screens/home_map_screen.dart';

abstract final class AppRoute {
  static const home = '/';
  static const dashboard = '/dashboard';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home,
    // Screen views come from each route's `name`.
    observers: [ref.watch(analyticsServiceProvider).observer],
    routes: [
      GoRoute(
        path: AppRoute.home,
        name: 'home',
        builder: (context, state) => const HomeMapScreen(),
      ),
      GoRoute(
        path: AppRoute.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});

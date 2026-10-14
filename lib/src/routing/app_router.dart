import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services/analytics_service.dart';
import '../ui/home_map/screens/home_map_screen.dart';

abstract final class AppRoute {
  static const home = '/';
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
    ],
  );
});

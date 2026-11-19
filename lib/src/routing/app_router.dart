import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/role_repository.dart';
import '../data/services/analytics_service.dart';
import '../ui/core/view_model/role_view_model.dart';
import '../ui/dashboard/screens/dashboard_screen.dart';
import '../ui/home_map/screens/home_map_screen.dart';
import '../ui/responder/screens/responder_console_screen.dart';
import '../ui/responder/screens/responder_login_screen.dart';
import '../ui/role/screens/role_selection_screen.dart';

abstract final class AppRoute {
  static const home = '/';
  static const dashboard = '/dashboard';
  static const role = '/role';
  static const responderLogin = '/responder/login';
  static const responder = '/responder';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // A fresh install chooses a role first; after that the app opens on the
  // saved side.
  final initialLocation = switch (ref.read(initialRoleProvider)) {
    null => AppRoute.role,
    AppRole.citizen => AppRoute.home,
    AppRole.responder => AppRoute.responder,
  };
  return GoRouter(
    initialLocation: initialLocation,
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
      GoRoute(
        path: AppRoute.role,
        name: 'role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoute.responderLogin,
        name: 'responder_login',
        builder: (context, state) => const ResponderLoginScreen(),
      ),
      GoRoute(
        path: AppRoute.responder,
        name: 'responder',
        builder: (context, state) => const ResponderConsoleScreen(),
      ),
    ],
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/auth/screens/auth_screen.dart';
import '../ui/dashboard/screens/dashboard_screen.dart';
import '../ui/facility_detail/screens/facility_detail_screen.dart';
import '../ui/get_help/screens/get_help_screen.dart';
import '../ui/home_map/screens/home_map_screen.dart';
import '../ui/live_tracking/screens/live_tracking_screen.dart';
import '../ui/triage_chat/screens/triage_chat_screen.dart';
import 'main_shell_screen.dart';

abstract final class AppRoute {
  static const home = '/';
  static const getHelp = '/get-help';
  static const liveTracking = '/live-tracking';
  static const facilityDetail = '/facility';
  static const triageChat = '/triage';
  static const auth = '/sign-in';
  static const dashboard = '/dashboard';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoute.home, builder: (context, state) => const HomeMapScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoute.triageChat, builder: (context, state) => const TriageChatScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoute.dashboard, builder: (context, state) => const DashboardScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.getHelp,
        builder: (context, state) => const GetHelpScreen(),
      ),
      GoRoute(
        path: AppRoute.liveTracking,
        builder: (context, state) => const LiveTrackingScreen(),
      ),
      GoRoute(
        path: AppRoute.facilityDetail,
        builder: (context, state) => const FacilityDetailScreen(),
      ),
      GoRoute(
        path: AppRoute.auth,
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
});

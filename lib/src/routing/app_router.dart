import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services/analytics_service.dart';
import '../ui/auth/screens/auth_screen.dart';
import '../ui/facility_detail/screens/facility_detail_screen.dart';
import '../ui/get_help/screens/get_help_screen.dart';
import '../ui/home_map/screens/home_map_screen.dart';
import '../ui/live_tracking/screens/live_tracking_screen.dart';

abstract final class AppRoute {
  static const home = '/';
  static const getHelp = '/get-help';
  static const liveTracking = '/live-tracking';
  static const facilityDetail = '/facility';
  static const auth = '/sign-in';
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
        path: AppRoute.getHelp,
        name: 'get_help',
        builder: (context, state) => const GetHelpScreen(),
      ),
      GoRoute(
        path: AppRoute.liveTracking,
        name: 'live_tracking',
        builder: (context, state) => const LiveTrackingScreen(),
      ),
      GoRoute(
        path: AppRoute.facilityDetail,
        name: 'facility_detail',
        builder: (context, state) => const FacilityDetailScreen(),
      ),
      GoRoute(
        path: AppRoute.auth,
        name: 'sign_in',
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
});

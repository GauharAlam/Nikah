import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'data/backend.dart';
import 'providers/app_store.dart';
import 'screens/approved_screen.dart';
import 'screens/contact_details_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/phone_signin_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/review_queue_screen.dart';
import 'screens/review_status_screen.dart';
import 'screens/start_profile_screen.dart';
import 'screens/about_screen.dart';
import 'screens/activities_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_tab_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/home_shell.dart';
import 'screens/islamic_practice_screen.dart';
import 'screens/landing_front_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/matches_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/photo_viewer_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/proposals_screen.dart';
import 'screens/schedule_meeting_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/wali_hub_screen.dart';
import 'screens/wali_onboarding_screen.dart';
import 'screens/wali_sms_portal_screen.dart';

/// Central table of routes. Replaces the old boolean-flag router and
/// restores system back-gesture behaviour on every sub-page.
class AppRoutes {
  static const String splash = '/splash';
  static const String landing = '/landing';
  static const String signIn = '/signin';
  static const String startProfile = '/start';
  static const String onboarding = '/onboarding';
  static const String reviewStatus = '/review/status';
  static const String approved = '/approved';
  static const String homeDiscovery = '/home/discovery';
  static const String homeProposals = '/home/proposals';
  static const String homeMatches = '/home/matches';
  static const String homeActivities = '/home/activities';
  static const String homePremium = '/home/premium';
  static const String homeChats = '/home/chat';
  static const String homeProfile = '/home/profile';
  static const String filters = '/filters';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String editProfile = '/profile/edit';
  static const String verifyProfile = '/profile/verify';
  static const String practice = '/profile/practice';
  static const String plans = '/plans';
  static const String contactDetails = '/profile/contact';
  static const String reviewQueue = '/admin/review';
  static const String waliHub = '/wali/hub';
  static const String waliOnboarding = '/wali/onboarding';
  static const String waliPortal = '/wali/portal';

  static String matchDetail(String id) => '/match/$id';
  static String chat(String id) => '/chat/$id';
  static String schedule(String id) => '/schedule/$id';
  static String photo(String id) => '/photo/$id';
}

/// Where [location] should go for the member's current state, or null to stay.
String? guardRoute(AppStore store, String location) {
  bool at(String path) => location == path;
  if (store.isRestoring) return at(AppRoutes.splash) ? null : AppRoutes.splash;

  final bool public = at(AppRoutes.landing) || at(AppRoutes.signIn);
  if (!store.isSignedIn) return public ? null : AppRoutes.landing;

  if (store.isLoggedIn) {
    if (!store.pledgeAccepted) {
      return at(AppRoutes.approved) ? null : AppRoutes.approved;
    }
    final bool entry = public ||
        location == '/' ||
        at(AppRoutes.splash) ||
        at(AppRoutes.startProfile) ||
        at(AppRoutes.onboarding) ||
        at(AppRoutes.reviewStatus) ||
        at(AppRoutes.approved);
    if (entry) return AppRoutes.homeDiscovery;
    final bool guardianRoute =
        location.startsWith('/wali') ||
        location.startsWith('/schedule') ||
        at(AppRoutes.practice);
    if (guardianRoute && !AppConfig.guardianFeatures) {
      return AppRoutes.homeDiscovery;
    }
    if (at(AppRoutes.reviewQueue) && !store.isReviewer) {
      return AppRoutes.homeDiscovery;
    }
    return null;
  }

  // Signed in, not approved.
  if (at(AppRoutes.verifyProfile)) return null;
  return switch (store.reviewStage) {
    ReviewStage.submitted =>
      at(AppRoutes.reviewStatus) ? null : AppRoutes.reviewStatus,
    ReviewStage.rejected =>
      at(AppRoutes.reviewStatus) || at(AppRoutes.onboarding)
          ? null
          : AppRoutes.reviewStatus,
    _ => at(AppRoutes.startProfile) || at(AppRoutes.onboarding)
        ? null
        : AppRoutes.startProfile,
  };
}

/// Builds the application router. [store] drives every redirect.
GoRouter buildRouter(AppStore store) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: store,
    redirect: (_, GoRouterState state) => guardRoute(store, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.landing, builder: (_, _) => const LandingScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const PhoneSignInScreen()),
      GoRoute(
        path: AppRoutes.startProfile,
        builder: (_, _) => const StartProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviewStatus,
        builder: (_, _) => const ReviewStatusScreen(),
      ),
      GoRoute(path: AppRoutes.approved, builder: (_, _) => const ApprovedScreen()),
      GoRoute(
        path: AppRoutes.practice,
        builder: (_, _) => const IslamicPracticeStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.contactDetails,
        builder: (_, _) => const ContactDetailsScreen(),
      ),
      GoRoute(path: AppRoutes.plans, builder: (_, _) => const PlansScreen()),
      GoRoute(
        path: AppRoutes.reviewQueue,
        builder: (_, _) => const ReviewQueueScreen(),
      ),

      // ── Main tabs shell (Barkat 6-tab layout) ─────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell shell) => HomeShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homeDiscovery,
              builder: (_, _) => const DiscoveryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homeProposals,
              builder: (_, _) => const ProposalsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homeMatches,
              builder: (_, _) => const MatchesHubScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homeActivities,
              builder: (_, _) => const ActivitiesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homePremium,
              builder: (_, _) => const PremiumScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.homeProfile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Global (sub) pages ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.homeChats,
        builder: (_, _) => const ChatTabScreen(),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (_, GoRouterState state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/schedule/:id',
        builder: (_, GoRouterState state) =>
            ScheduleMeetingScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.filters, builder: (_, _) => const FiltersScreen()),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: AppRoutes.about, builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyProfile,
        builder: (_, _) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (_, GoRouterState state) {
          final String id = state.pathParameters['id']!;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: ChatScreen(matchId: id),
            transitionsBuilder: (_, Animation<double> animation,
                    _, Widget child) =>
                FadeTransition(opacity: animation, child: child),
          );
        },
      ),
      GoRoute(
        path: '/photo/:id',
        builder: (_, GoRouterState state) => PhotoViewerScreen(
          imageUrl: state.uri.queryParameters['url'] ?? '',
          personName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: AppRoutes.waliHub,
        builder: (_, _) => const WaliHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.waliOnboarding,
        builder: (_, _) => const WaliOnboardingStepScreen(isStandalone: true),
      ),
      GoRoute(
        path: AppRoutes.waliPortal,
        builder: (_, _) => const WaliSmsPortalScreen(),
      ),
    ],
    errorBuilder: (_, GoRouterState state) => const _NotFoundScreen(),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Page not found')));
  }
}

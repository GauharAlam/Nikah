import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_store.dart';
import 'screens/about_screen.dart';
import 'screens/activities_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_tab_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/education_career_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/home_shell.dart';
import 'screens/islamic_practice_screen.dart';
import 'screens/landing_front_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/matches_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/photo_viewer_screen.dart';
import 'screens/photos_verification_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/proposals_screen.dart';
import 'screens/review_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/schedule_meeting_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/welcome_intentions_screen.dart';
import 'screens/wali_hub_screen.dart';
import 'screens/wali_onboarding_screen.dart';
import 'screens/wali_sms_portal_screen.dart';

/// Central table of routes. Replaces the old boolean-flag router and
/// restores system back-gesture behaviour on every sub-page.
class AppRoutes {
  static const String landing = '/landing';
  static const String welcome = '/welcome';
  static const String signIn = '/signin';
  static const String onboardingAccount = '/onboarding/account';
  static const String onboardingEducation = '/onboarding/education';
  static const String onboardingPractice = '/onboarding/practice';
  static const String onboardingPhotos = '/onboarding/photos';
  static const String onboardingWali = '/onboarding/wali';
  static const String onboardingBiodata = '/onboarding/biodata';
  static const String onboardingReview = '/onboarding/review';
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
  static const String waliHub = '/wali/hub';
  static const String waliOnboarding = '/wali/onboarding';
  static const String waliPortal = '/wali/portal';

  static String matchDetail(String id) => '/match/$id';
  static String chat(String id) => '/chat/$id';
  static String schedule(String id) => '/schedule/$id';
  static String photo(String id) => '/photo/$id';
}

/// Builds the application router. [store] is the shared state instance
/// (also provided through Provider) used for redirect decisions.
GoRouter buildRouter(AppStore store) {
  String redirectForPath(String path) {
    if (path == '/') {
      return store.isLoggedIn ? AppRoutes.homeDiscovery : AppRoutes.landing;
    }
    final bool inOnboarding = path.startsWith('/onboarding');
    if (inOnboarding && !store.isOnboarding && store.hasCompletedOnboarding) {
      return AppRoutes.homeDiscovery;
    }
    return path;
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: store,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (_, GoRouterState state) {
          final String target = redirectForPath('/');
          return target == state.matchedLocation ? null : target;
        },
      ),
      GoRoute(path: AppRoutes.landing, builder: (_, _) => const LandingScreen()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeIntentionsScreen(),
      ),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),

      // ── Onboarding flow (6 steps + review) ────────────────────────────────
      GoRoute(
        path: AppRoutes.onboardingAccount,
        builder: (_, _) => const CreateAccountStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingEducation,
        builder: (_, _) => const EducationCareerStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPractice,
        builder: (_, _) => const IslamicPracticeStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPhotos,
        builder: (_, _) => const PhotosVerificationStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingWali,
        builder: (_, _) => const WaliOnboardingStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingBiodata,
        builder: (_, _) => const BiodataStepScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingReview,
        builder: (_, _) => const ReviewStepScreen(),
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

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Page not found')));
  }
}

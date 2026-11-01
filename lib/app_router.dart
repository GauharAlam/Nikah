import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/backend.dart';
import 'providers/app_store.dart';
import 'screens/approved_screen.dart';
import 'screens/account_screens.dart';
import 'screens/contact_details_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/phone_signin_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/review_queue_screen.dart';
import 'screens/review_status_screen.dart';
import 'screens/safety_center_screen.dart';
import 'screens/start_profile_screen.dart';
import 'screens/about_screen.dart';
import 'screens/activities_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_tab_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/family_circle_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/home_shell.dart';
import 'screens/islamic_practice_screen.dart';
import 'screens/journey_screen.dart';
import 'screens/landing_front_screen.dart';
import 'screens/match_detail_screen.dart';
import 'screens/matches_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/photo_viewer_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/proposals_screen.dart';
import 'screens/schedule_meeting_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/wali_hub_screen.dart';
import 'screens/wali_onboarding_screen.dart';
import 'screens/wali_sms_portal_screen.dart';
import 'theme/app_theme.dart';

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
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String editProfile = '/profile/edit';
  static const String verifyProfile = '/profile/verify';
  static const String practice = '/profile/practice';
  static const String plans = '/plans';
  static const String safety = '/safety';
  static const String invite = '/invite';
  static const String familyCircle = '/family/circle';
  static const String familyView = '/family/view';
  static const String deleteAccount = '/settings/delete';
  static const String blockedMembers = '/settings/blocked';
  static const String contactDetails = '/profile/contact';
  static const String verifyPhone = '/profile/phone';
  static const String reviewQueue = '/admin/review';
  static const String waliHub = '/wali/hub';
  static const String waliOnboarding = '/wali/onboarding';
  static const String waliPortal = '/wali/portal';

  static String matchDetail(String id) => '/match/$id';
  static String chat(String id) => '/chat/$id';
  static String journey(String id) => '/journey/$id';
  static String schedule(String id) => '/schedule/$id';
  static String photo(String id) => '/photo/$id';
}

/// The screens a notification may open. Anything else is ignored, so a
/// malformed or forged link can never reach an arbitrary route or URL.
String? safeDeepLink(Object? link) {
  if (link is! String) return null;
  const Set<String> fixed = <String>{
    AppRoutes.homeDiscovery, AppRoutes.homeProposals, AppRoutes.homeMatches, AppRoutes.homeActivities,
    AppRoutes.notifications, AppRoutes.reviewStatus, AppRoutes.verifyProfile, AppRoutes.editProfile,
    AppRoutes.familyCircle, AppRoutes.familyView, AppRoutes.invite,
  };
  if (fixed.contains(link)) return link;
  return RegExp(r'^/(chat|match)/[A-Za-z0-9_-]{1,128}$').hasMatch(link) ? link : null;
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
        location.startsWith('/schedule');
    if (guardianRoute && !AppConfig.guardianFeatures) {
      return AppRoutes.homeDiscovery;
    }
    if (at(AppRoutes.reviewQueue) && !store.isReviewer) {
      return AppRoutes.homeDiscovery;
    }
    return null;
  }

  // Signed in, not approved.
  if (at(AppRoutes.verifyProfile) ||
      at(AppRoutes.verifyPhone) ||
      at(AppRoutes.practice) ||
      at(AppRoutes.safety) ||
      at(AppRoutes.familyView)) {
    return null;
  }
  // Someone who joined only as family has no profile of their own to finish.
  if (store.isGuardian && store.reviewStage == ReviewStage.draft) {
    return AppRoutes.familyView;
  }
  return switch (store.reviewStage) {
    ReviewStage.submitted =>
      at(AppRoutes.reviewStatus) ? null : AppRoutes.reviewStatus,
    ReviewStage.rejected || ReviewStage.changesRequested =>
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
        path: AppRoutes.verifyPhone,
        builder: (_, _) => const PhoneSignInScreen(linking: true),
      ),
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
      GoRoute(path: AppRoutes.invite, builder: (_, _) => const InviteScreen()),
      GoRoute(
        path: AppRoutes.familyCircle,
        builder: (_, _) => const FamilyCircleScreen(),
      ),
      GoRoute(
        path: AppRoutes.familyView,
        builder: (_, _) => const FamilyViewScreen(),
      ),
      GoRoute(path: AppRoutes.safety, builder: (_, _) => const SafetyCenterScreen()),
      GoRoute(
        path: '/journey/:id',
        builder: (_, GoRouterState state) =>
            JourneyScreen(matchId: state.pathParameters['id']!),
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
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: AppRoutes.deleteAccount, builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: AppRoutes.blockedMembers, builder: (_, _) => const BlockedMembersScreen()),
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

/// Shown until the session is known. Never shows member content, and offers a
/// retry when start-up fails instead of spinning forever.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final String? error = store.startupError;
    return Scaffold(
      backgroundColor: AppTheme.emeraldDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.mosque, size: 48, color: AppTheme.gold),
              const SizedBox(height: 14),
              Text(AppBrand.name, style: AppTheme.ts(24, FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 26),
              if (error == null)
                const CircularProgressIndicator(color: AppTheme.gold)
              else ...<Widget>[
                Text(
                  error,
                  key: const Key('startup_error'),
                  textAlign: TextAlign.center,
                  style: AppTheme.ts(14, FontWeight.w500, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('startup_retry'),
                  onPressed: store.retryStartup,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Page not found')));
  }
}

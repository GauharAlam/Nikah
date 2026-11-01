import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../models/meeting.dart';
import '../models/nikah_journey.dart';
import '../models/notification_item.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';
import '../models/wali.dart';
import '../models/ward_profile.dart';

export '../features/session/session_controller.dart' show AuthStage;
export 'remote_app_store.dart';

/// What screens see. [RemoteAppStore] is the production implementation and
/// delegates to feature controllers. `DemoAppStore` is a debug-only simulation.
///
/// New screens should read a feature controller directly; this interface stays
/// while existing screens move across.
abstract class AppStore extends ChangeNotifier {
  AppStore(this.prefs) {
    AppStrings.current =
        AppLanguage.values.asNameMap()[prefs.getString(_kLanguage)] ?? AppLanguage.english;
  }

  final SharedPreferences prefs;

  /// Failures to show the member. Screens never need to catch these.
  final ValueNotifier<String?> errors = ValueNotifier<String?>(null);

  Backend? get backend => null;

  // ─── Language ─────────────────────────────────────────────────────────────
  static const String _kLanguage = 'bk_language';

  AppLanguage get language => AppStrings.current;

  void setLanguage(AppLanguage next) {
    AppStrings.current = next;
    unawaited(prefs.setString(_kLanguage, next.name));
    notifyListeners();
  }

  // ─── Session ──────────────────────────────────────────────────────────────
  String get uid;
  bool get isRestoring;
  bool get isSignedIn;
  bool get isLoggedIn;
  bool get isReviewer;
  ReviewStage get reviewStage;
  String get rejectionReason;
  bool get pledgeAccepted;
  void acceptPledge();
  Future<String> sendOtp(String e164Phone);
  Future<void> confirmOtp(String verificationId, String code);
  Future<void> signInWithGoogle();
  void signOut();
  void enterOnboarding();

  /// Deletes the member's account and clears this device.
  void resetAll();

  // ─── Limits ───────────────────────────────────────────────────────────────
  int get dailyProposalLimit;
  int get monthlyCredits;
  int get decisionsPerDay;
  int get pendingLimit;
  bool get requireIdProof;
  bool get graduatesOnly;
  bool get isPremium;
  DateTime? get premiumUntil;
  int get proposalsSentToday;
  int get proposalsLeft;
  int get contactCredits;
  int? get freeProfilesLeft;
  bool get reachedProfileLimit;
  int get freeProfileAllowance;

  // ─── Draft and verification ───────────────────────────────────────────────
  WardProfile? get profile;
  void updateProfile(WardProfile Function(WardProfile) mutate);
  Future<void> saveDraft(WardProfile next);
  Future<String> uploadPhoto(String localPath);
  Future<String> photoSource(String stored);
  Future<void> removePhoto(String stored);
  Future<void> submitProfile();
  void submitEdits();
  void updatePrivacy({String? photoPrivacy, bool? showCaste, bool? allowFamilyShare});
  List<VerificationDoc> get verificationDocs;
  bool get isBarkatVerified;
  int get verificationProgress;
  Future<void> uploadVerificationDoc(String docId, List<String> localPaths);

  // ─── Discovery ────────────────────────────────────────────────────────────
  List<MatchProfile> get directory;
  MatchProfile profileById(String id);
  List<MatchProfile> get discoveredProfiles;
  MatchFilters get filters;
  void setFilters(MatchFilters next);
  bool get isLoadingIntroductions;
  String? get introductionsError;
  Future<void> refreshIntroductions();
  Future<void> loadMoreIntroductions();
  void markProfileViewed(String id);
  void markIncompatible(String matchId);

  // ─── Proposals and contact ────────────────────────────────────────────────
  Proposal? incomingProposal(String matchId);
  Proposal? outgoingProposal(String matchId);
  bool hasProposed(String matchId);
  List<Proposal> get sentProposals;
  List<Proposal> get pendingIncomingProposals;
  int get pendingRequestCount;
  bool sendProposal(String matchId);
  bool acceptProposal(String matchId);
  bool declineProposal(String matchId);
  bool withdrawProposal(String matchId);
  bool contactRequested(String matchId);
  bool isContactShared(String matchId);
  bool requestContact(String matchId);
  List<MatchProfile> get incomingContactRequests;
  Future<void> respondContact(String matchId, {required bool accept});
  String sharedPhone(String matchId);

  // ─── Matches and chat ─────────────────────────────────────────────────────
  bool isApproved(String matchId);
  List<MatchProfile> get chatMatches;
  List<MatchProfile> get sharedContactProfiles;
  List<String> get chatThreadIds;
  List<ChatMessage> messages(String matchId);
  String lastMessagePreview(String matchId);
  int unreadCount(String matchId);
  int get totalUnread;
  void markThreadRead(String matchId);
  void sendMessage(String matchId, String text);
  void unmatch(String matchId);
  bool isBlocked(String matchId);
  void blockProfile(String matchId);
  void reportProfile(String matchId, String reason);

  // ─── Nikah Journey ────────────────────────────────────────────────────────
  JourneyStep journeyStep(String matchId);
  JourneyStep? theirJourneyStep(String matchId);
  void setJourneyStep(String matchId, JourneyStep step);
  Future<Map<String, String>> myAnswers(String matchId);
  Future<Map<String, String>?> theirAnswers(String matchId);
  Future<void> saveAnswers(String matchId, Map<String, String> answers);

  // ─── Family and invites ───────────────────────────────────────────────────
  FamilyState get family;
  FamilyState? get guardianView;
  bool get isGuardian;
  Future<String> createFamilyInvite();
  Future<void> joinFamily(String code, String name);
  Future<void> removeGuardian(String guardian);
  Future<void> shareWithFamily(String profileId);
  void giveFamilyOpinion(String profileId, String opinion);
  Future<InviteInfo> inviteInfo();

  // ─── Notifications and settings ───────────────────────────────────────────
  List<NotificationItem> get notifications;
  int get unreadNotificationCount;
  void markNotificationRead(String id);
  void markAllNotificationsRead();
  bool get showArabic;
  void setShowArabic(bool value);

  // ─── Purchases ────────────────────────────────────────────────────────────
  /// Grants nothing locally: entitlements come from the server only.
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
    String? packageName,
  });

  // ─── Demo-only surfaces ───────────────────────────────────────────────────
  // Guardian portal, meetings and the local timeline have no server support.
  // `AppConfig.guardianFeatures` keeps them out of production, where these
  // members stay inert so no seeded person can ever appear.
  Guardian get guardian => Guardian.none;
  void updateGuardian(Guardian next) {}
  void setOnboardingGuardian(Guardian next) {}
  void verifyGuardianSms() {}
  bool privacy(String key) => false;
  void togglePrivacy(String key, bool value) {}
  List<ActivityLogEntry> get activityLog => const <ActivityLogEntry>[];
  List<MeetingRequest> get meetings => const <MeetingRequest>[];
  MeetingRequest? get nextMeeting => null;
  void scheduleMeeting(MeetingRequest request) {}
  bool get pushEnabled => true;
  void setPushEnabled(bool value) {}
  bool get emailDigest => false;
  void setEmailDigest(bool value) {}

  // ─── Formatting helpers shared with screens ───────────────────────────────
  static String privacyLabel(String key) => switch (key) {
        'blurPhotos' => 'Photo modesty blur',
        'readReceipts' => 'Read receipts for matches',
        'activityAlerts' => 'Guardian activity alerts',
        'chatChaperone' => 'Chaperoned chat audit',
        'hideFromNonVerified' => 'Hide me from non-verified members',
        _ => key,
      };

  static String fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${two(hour)}:${two(dt.minute)} $suffix';
  }

  static String fmtDate(DateTime dt) {
    const List<String> days = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

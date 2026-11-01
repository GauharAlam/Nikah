import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../features/discovery/discovery_controller.dart';
import '../features/family/family_controller.dart';
import '../features/messaging/chat_controller.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/profiles/profile_controller.dart';
import '../features/proposals/connections_controller.dart';
import '../features/session/session_controller.dart';
import '../features/settings/settings_controller.dart';
import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../models/nikah_journey.dart';
import '../models/notification_item.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';
import '../models/wali.dart';
import '../models/ward_profile.dart';
import 'app_store.dart';

/// Production [AppStore]. Owns the feature controllers, starts and stops them
/// with the auth session, and forwards screen calls to them. The server stays
/// the only source of truth: mutations go out, results return through streams.
class RemoteAppStore extends AppStore {
  RemoteAppStore(super.prefs, this._backend) {
    session = SessionController(_backend, _report, prefs);
    drafts = ProfileController(_backend, _report, session);
    discovery = DiscoveryController(_backend, _report, session, prefs);
    chat = ChatController(_backend, _report, session, discovery);
    connections = ConnectionsController(_backend, _report, session, discovery, chat);
    circle = FamilyController(_backend, _report, session);
    inbox = NotificationsController(_backend, _report, session);
    settings = SettingsController(prefs);
    session.onFamilyLink = circle.link;
    for (final Listenable c in <Listenable>[
      session, drafts, discovery, chat, connections, circle, inbox, settings,
    ]) {
      c.addListener(notifyListeners);
    }
    _authSub = _backend.authChanges.listen(_onAuth, onError: (Object _) {
      session.failStart('We could not check your sign-in. Please try again.');
    });
  }

  final Backend _backend;
  StreamSubscription<AuthUser?>? _authSub;

  late final SessionController session;
  late final ProfileController drafts;
  late final DiscoveryController discovery;
  late final ChatController chat;
  late final ConnectionsController connections;
  late final FamilyController circle;
  late final NotificationsController inbox;
  late final SettingsController settings;

  void _report(Object error) {
    errors.value = error is BackendException
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  /// Runs a server call; failures surface through [errors].
  void _send(Future<void> Function() call) {
    unawaited(() async {
      try {
        await call();
      } on Object catch (e) {
        _report(e);
      }
    }());
  }

  Future<void> _stopAll() async {
    await session.stop();
    await drafts.stop();
    await discovery.stop();
    await chat.stop();
    await connections.stop();
    await circle.stop();
    await inbox.stop();
  }

  Future<void> _onAuth(AuthUser? user) async {
    if (user != null && user.uid == session.uid) {
      if (session.refresh(user)) unawaited(discovery.refresh());
      return;
    }
    await _stopAll();
    if (user == null) {
      session.signedOut();
      return;
    }
    session.begin(user);
    await _startSession(user);
  }

  Future<void> _startSession(AuthUser user) async {
    if (!await drafts.loadDraft(user)) {
      session.failStart('We could not load your profile. Check your connection and try again.');
      return;
    }
    final String uid = user.uid;
    session.start(uid);
    session.followPurchases(uid);
    circle.start(uid);
    discovery.start();
    connections.start(uid);
    chat.start(uid);
    inbox.start(uid);
    drafts.start(uid);
    _send(() => _backend.registerPushToken(uid));
    if (user.isApproved) _send(_backend.touchActive);
    session.restored();
  }

  // ─── Session ──────────────────────────────────────────────────────────────
  @override
  Backend get backend => _backend;
  @override
  String get uid => session.uid;
  @override
  bool get isRestoring => session.isRestoring;
  @override
  bool get isSignedIn => session.isSignedIn;
  @override
  bool get isLoggedIn => session.isActive;
  @override
  bool get isReviewer => session.isReviewer;
  @override
  ReviewStage get reviewStage => session.reviewStage;
  @override
  String get rejectionReason => session.account.rejectionReason;
  @override
  bool get pledgeAccepted => session.pledgeAccepted;
  @override
  void acceptPledge() => session.acceptPledge();
  @override
  String get verifiedPhone => session.user?.phone ?? '';
  @override
  String? get startupError => session.startupError;
  @override
  void retryStartup() {
    final AuthUser? user = session.user;
    if (user == null) return;
    session.clearStartupError();
    unawaited(_startSession(user));
  }

  @override
  Future<String?> sendOtp(String e164Phone) => _backend.sendOtp(e164Phone);
  @override
  Future<void> confirmOtp(String verificationId, String code) =>
      _backend.confirmOtp(verificationId, code);
  @override
  Future<void> signInWithGoogle() => _backend.signInWithGoogle();
  @override
  void signOut() => _send(_backend.signOut);
  @override
  void enterOnboarding() {}

  @override
  Future<void> deleteAccount() async {
    await _backend.deleteAccount();
    await prefs.clear();
  }

  // ─── Limits ───────────────────────────────────────────────────────────────
  @override
  int get dailyProposalLimit => session.limits.proposalsPerDay;
  @override
  int get monthlyCredits => session.limits.monthlyContactCredits;
  @override
  int get decisionsPerDay => session.limits.decisionsPerDay;
  @override
  int get pendingLimit => session.limits.pendingLimit;
  @override
  bool get requireIdProof => session.limits.requireIdProof;
  @override
  bool get graduatesOnly => session.limits.graduatesOnly;
  @override
  bool get isPremium => session.isPremium;
  @override
  DateTime? get premiumUntil => session.account.premiumUntil;
  @override
  int get proposalsSentToday => session.account.proposalsSentToday;
  @override
  int get proposalsLeft => connections.proposalsLeft;
  @override
  int get contactCredits => connections.contactCredits;
  @override
  int? get freeProfilesLeft => discovery.freeLeft;
  @override
  bool get reachedProfileLimit => discovery.limitReached;
  @override
  int get freeProfileAllowance => discovery.freeLimit;

  // ─── Draft and verification ───────────────────────────────────────────────
  @override
  WardProfile? get profile => drafts.profile;
  @override
  void updateProfile(WardProfile Function(WardProfile) mutate) => drafts.updateProfile(mutate);
  @override
  Future<void> saveDraft(WardProfile next) => drafts.saveDraft(next);
  @override
  Future<String> uploadPhoto(String localPath, {void Function(double)? onProgress}) =>
      drafts.uploadPhoto(localPath, onProgress: onProgress);
  @override
  List<String> get rejectedPhotos => session.account.rejectedPhotos;
  @override
  Future<String> photoSource(String stored) => _backend.photoUrl(stored);
  @override
  Future<void> removePhoto(String stored) => drafts.removePhoto(stored);
  @override
  Future<void> submitProfile() => _backend.submitProfile();
  @override
  void submitEdits() => drafts.submitEdits();
  @override
  void updatePrivacy({
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? nearbyOptIn,
    bool? allowContactRequests,
  }) =>
      drafts.updatePrivacy(
        photoPrivacy: photoPrivacy,
        showCaste: showCaste,
        allowFamilyShare: allowFamilyShare,
        nearbyOptIn: nearbyOptIn,
        allowContactRequests: allowContactRequests,
      );
  @override
  bool get isPaused => session.account.paused;
  @override
  Future<void> setPaused(bool paused) => _backend.setPaused(paused);
  @override
  Future<List<BlockedMember>> blockedMembers() => _backend.listBlocks();
  @override
  Future<void> unblockProfile(String id) => _backend.unblockProfile(id);
  @override
  Future<String> exportData() async =>
      const JsonEncoder.withIndent('  ').convert(await _backend.exportMyData());
  @override
  String get subjectCode => session.account.subjectCode;
  @override
  bool get subjectConfirmed => session.account.subjectConfirmed;
  @override
  bool get isSubjectOfProfile => session.account.subjectOf != null;
  @override
  Future<void> confirmSubject(String code, {required bool agree}) =>
      _backend.confirmSubject(code, agree: agree);
  @override
  Future<void> withdrawSubject() => _backend.withdrawSubject();
  @override
  List<VerificationDoc> get verificationDocs => drafts.documents;
  @override
  bool get isBarkatVerified => drafts.isVerified;
  @override
  int get verificationProgress => drafts.verificationProgress;
  @override
  Future<void> uploadVerificationDoc(String docId, List<String> localPaths) =>
      drafts.uploadVerificationDoc(docId, localPaths);

  // ─── Discovery ────────────────────────────────────────────────────────────
  @override
  List<MatchProfile> get directory => discovery.directory;
  @override
  MatchProfile profileById(String id) => discovery.profileById(id);
  @override
  Future<void> loadFullProfile(String id) => discovery.loadFull(id);
  @override
  List<MatchProfile> get discoveredProfiles => discovery.introductions;
  @override
  MatchFilters get filters => discovery.filters;
  @override
  void setFilters(MatchFilters next) => discovery.setFilters(next);
  @override
  bool get isLoadingIntroductions => discovery.isLoading;
  @override
  String? get introductionsError => discovery.error;
  @override
  Future<void> refreshIntroductions() => discovery.refresh();
  @override
  Future<void> loadMoreIntroductions() => discovery.loadMore();
  @override
  void markProfileViewed(String id) {}
  @override
  void markIncompatible(String matchId) => discovery.markIncompatible(matchId);
  @override
  Future<IntroductionPage> searchProfiles({required String query, required bool nearby, int? cursor}) =>
      discovery.search(query: query, nearby: nearby, cursor: cursor);

  // ─── Proposals and contact ────────────────────────────────────────────────
  @override
  Proposal? incomingProposal(String matchId) => connections.incoming(matchId);
  @override
  Proposal? outgoingProposal(String matchId) => connections.outgoing(matchId);
  @override
  bool hasProposed(String matchId) => connections.hasProposed(matchId);
  @override
  List<Proposal> get sentProposals => connections.sent;
  @override
  List<Proposal> get pendingIncomingProposals => connections.pendingIncoming;
  @override
  int get pendingRequestCount => connections.pendingIncoming.length;
  @override
  bool sendProposal(String matchId) => connections.sendProposal(matchId);
  @override
  bool acceptProposal(String matchId) => connections.accept(matchId);
  @override
  bool declineProposal(String matchId) => connections.decline(matchId);
  @override
  bool withdrawProposal(String matchId) => connections.withdraw(matchId);
  @override
  bool contactRequested(String matchId) => connections.contactRequested(matchId);
  @override
  bool isContactShared(String matchId) => connections.isContactShared(matchId);
  @override
  bool requestContact(String matchId) => connections.requestContact(matchId);
  @override
  List<MatchProfile> get incomingContactRequests => connections.incomingContactRequests;
  @override
  Future<void> respondContact(String matchId, {required bool accept}) =>
      connections.respondContact(matchId, accept: accept);
  @override
  String sharedPhone(String matchId) => connections.sharedPhone(matchId);

  // ─── Matches and chat ─────────────────────────────────────────────────────
  @override
  bool isApproved(String matchId) => chat.isMatched(matchId);
  @override
  List<MatchProfile> get chatMatches => connections.chatMatches;
  @override
  List<MatchProfile> get sharedContactProfiles => connections.sharedContactProfiles;
  @override
  List<String> get chatThreadIds => chat.threadIds;
  @override
  List<ChatMessage> messages(String matchId) => chat.messages(matchId);
  @override
  String lastMessagePreview(String matchId) => chat.preview(matchId);
  @override
  int unreadCount(String matchId) => chat.unreadCount(matchId);
  @override
  int get totalUnread => chat.totalUnread;
  @override
  void markThreadRead(String matchId) => chat.markRead(matchId);
  @override
  void sendMessage(String matchId, String text) => chat.sendMessage(matchId, text);
  @override
  void unmatch(String matchId) => chat.unmatch(matchId);
  @override
  bool isBlocked(String matchId) => discovery.isBlocked(matchId);
  @override
  Future<void> blockProfile(String matchId) => discovery.block(matchId);
  @override
  Future<void> reportProfile(String matchId, String reason, {String details = '', String context = 'profile'}) =>
      _backend.reportProfile(matchId, reason, details: details, context: context);
  @override
  void openThread(String matchId) => chat.openThread(matchId);
  @override
  void closeThread() => chat.closeThread();
  @override
  bool isThreadOpen(String matchId) => chat.isMatched(matchId);
  @override
  bool isSeen(String matchId, ChatMessage message) => chat.isSeen(matchId, message);
  @override
  void retryMessage(String matchId, String messageId) => chat.retry(matchId, messageId);
  @override
  Future<void> loadOlderMessages() => chat.loadOlder();
  @override
  bool get reachedChatStart => chat.reachedStart;
  @override
  List<MatchProfile> get closedMatches =>
      chat.closedIds.map(discovery.profileById).toList();
  @override
  List<MatchProfile> get pendingContacts => connections.pendingContacts;

  // ─── Nikah Journey ────────────────────────────────────────────────────────
  @override
  JourneyStep journeyStep(String matchId) => chat.journeyStep(matchId);
  @override
  JourneyStep? theirJourneyStep(String matchId) => chat.theirJourneyStep(matchId);
  @override
  void setJourneyStep(String matchId, JourneyStep step) => chat.setJourneyStep(matchId, step);
  @override
  Future<Map<String, String>> myAnswers(String matchId) => chat.myAnswers(matchId);
  @override
  Future<Map<String, String>?> theirAnswers(String matchId) => chat.theirAnswers(matchId);
  @override
  Future<void> saveAnswers(String matchId, Map<String, String> answers) =>
      chat.saveAnswers(matchId, answers);

  // ─── Family and invites ───────────────────────────────────────────────────
  @override
  FamilyState get family => circle.family;
  @override
  FamilyState? get guardianView => circle.guardianView;
  @override
  bool get isGuardian => session.account.familyOf != null;
  @override
  FamilyAdmin get familyAdmin => circle.admin;
  @override
  Future<String> createFamilyInvite({
    required String name,
    required String relationship,
    required String phone,
    required List<String> permissions,
  }) =>
      circle.createInvite(name: name, relationship: relationship, phone: phone, permissions: permissions);
  @override
  Future<void> joinFamily(String code) => circle.join(code);
  @override
  Future<void> rejectFamilyInvite(String code) => _backend.rejectFamilyInvite(code);
  @override
  Future<void> cancelFamilyInvite(String id) => _backend.cancelFamilyInvite(id);
  @override
  Future<String> resendFamilyInvite(String id) => _backend.resendFamilyInvite(id);
  @override
  Future<void> updateGuardianPermissions(String guardian, List<String> permissions) =>
      _backend.updateGuardianPermissions(guardian, permissions);
  @override
  Future<FamilyOverview?> familyOverview() => circle.overview();
  @override
  Future<void> answerForMember(String from, {required bool accept}) =>
      circle.answerForMember(from, accept: accept);
  @override
  Future<void> removeGuardian(String guardian) => circle.removeGuardian(guardian);
  @override
  Future<void> leaveFamily() => circle.leave();
  @override
  Future<void> shareWithFamily(String profileId) => circle.share(profileId);
  @override
  void giveFamilyOpinion(String profileId, String opinion) =>
      circle.giveOpinion(profileId, opinion);
  @override
  Future<InviteInfo> inviteInfo() => _backend.getInviteCode();

  // ─── Notifications and settings ───────────────────────────────────────────
  @override
  List<NotificationItem> get notifications => inbox.items;
  @override
  int get unreadNotificationCount => inbox.unreadCount;
  @override
  void markNotificationRead(String id) => inbox.markRead(id);
  @override
  void markAllNotificationsRead() => inbox.markAllRead();

  /// The timeline is the member's real server notifications.
  @override
  List<ActivityLogEntry> get activityLog => inbox.items
      .map((NotificationItem n) => ActivityLogEntry(
            id: n.id,
            kind: switch (n.type) {
              NotificationType.chat => ActivityKind.chat,
              NotificationType.intro || NotificationType.match => ActivityKind.intro,
              _ => ActivityKind.general,
            },
            title: n.title,
            detail: n.body,
            createdAt: n.createdAt,
          ))
      .toList();
  @override
  bool get showArabic => settings.showArabic;
  @override
  void setShowArabic(bool value) => settings.setShowArabic(value);

  // ─── Purchases ────────────────────────────────────────────────────────────
  @override
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
  }) =>
      _backend.validatePurchase(productId: productId, platform: platform, token: token);
  @override
  Set<String> get subscriptionProductIds => session.limits.subscriptionIds;
  @override
  Set<String> get creditProductIds => session.limits.creditIds;
  @override
  List<PurchaseRecord> get purchases => session.purchases;
  @override
  bool wantsNotification(String category) => inbox.wants(category);
  @override
  void setWantsNotification(String category, bool on) => inbox.setWants(category, on);

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    session.dispose();
    drafts.dispose();
    discovery.dispose();
    chat.dispose();
    connections.dispose();
    circle.dispose();
    inbox.dispose();
    settings.dispose();
    super.dispose();
  }
}

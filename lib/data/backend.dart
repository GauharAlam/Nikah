import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../models/notification_item.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';

/// Review progress of a member's profile. Owned by the server.
enum ReviewStage { draft, submitted, approved, rejected }

class AuthUser {
  const AuthUser({
    required this.uid,
    this.phone = '',
    this.email = '',
    this.isApproved = false,
    this.isReviewer = false,
  });

  final String uid;
  final String phone;
  final String email;
  final bool isApproved;
  final bool isReviewer;
}

/// Server-owned account state. The client only ever reads this.
class AccountState {
  const AccountState({
    this.stage = ReviewStage.draft,
    this.rejectionReason = '',
    this.proposalsSentToday = 0,
    this.decisionsToday = 0,
    this.contactCreditsLeft = 0,
    this.premiumUntil,
    this.plan = '',
    this.familyOf,
  });

  final ReviewStage stage;
  final String rejectionReason;
  final int proposalsSentToday;
  final int decisionsToday;

  /// Purchased credits minus credits spent this month. The monthly allowance
  /// comes from [AppLimits].
  final int contactCreditsLeft;
  final DateTime? premiumUntil;
  final String plan;

  /// The member whose circle this account belongs to, if any.
  final String? familyOf;

  bool get isPremium =>
      premiumUntil != null && premiumUntil!.isAfter(DateTime.now());
}

/// Quotas served from `config/app`.
class AppLimits {
  const AppLimits({
    this.proposalsPerDay = 5,
    this.decisionsPerDay = 10,
    this.pendingLimit = 15,
    this.monthlyContactCredits = 30,
    this.requireIdProof = true,
    this.graduatesOnly = true,
  });

  final int proposalsPerDay;
  final int decisionsPerDay;
  final int pendingLimit;
  final int monthlyContactCredits;
  final bool requireIdProof;
  final bool graduatesOnly;
}

class IntroductionPage {
  const IntroductionPage(
    this.profiles,
    this.cursor, {
    this.freeLeft,
    this.freeLimit = 15,
    this.limitReached = false,
  });
  final List<MatchProfile> profiles;

  /// Free views left. Null for premium members.
  final int? freeLeft;
  final int freeLimit;
  final bool limitReached;

  /// Null when there is nothing further to load.
  final int? cursor;
}

/// One open or closed match, seen from this member's side.
class MatchThread {
  const MatchThread({
    required this.pairId,
    required this.otherId,
    required this.isOpen,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unread = 0,
    this.myStep,
    this.theirStep,
  });

  final String pairId;
  final String otherId;
  final bool isOpen;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final String? myStep;
  final String? theirStep;
}

class ContactRequestRecord {
  const ContactRequestRecord({
    required this.profileId,
    required this.isIncoming,
    required this.status,
  });

  final String profileId;
  final bool isIncoming;
  final String status;
}

class InviteInfo {
  const InviteInfo(this.code, this.invited, this.earned);
  final String code;
  final int invited;
  final int earned;
}

/// A profile summary shared with family. Never holds a photo or contact.
class FamilyPick {
  const FamilyPick({
    required this.id,
    required this.title,
    required this.summary,
    this.opinions = const <String, String>{},
  });

  final String id;
  final String title;
  final String summary;

  /// Guardian uid to opinion.
  final Map<String, String> opinions;
}

class FamilyState {
  const FamilyState({
    this.guardians = const <String, String>{},
    this.shortlist = const <FamilyPick>[],
  });

  /// Guardian uid to display name.
  final Map<String, String> guardians;
  final List<FamilyPick> shortlist;
}

/// What a screen should do about a failure.
enum FailureKind { offline, notAllowed, notFound, limitReached, recentSignInNeeded, invalid, other }

/// Server failure with text that is safe to show a member.
class BackendException implements Exception {
  const BackendException(this.message, {this.code = ''});
  final String message;
  final String code;

  FailureKind get kind => kindOf(code);

  /// Maps Firebase error codes to the action a screen should take.
  static FailureKind kindOf(String code) => switch (code) {
        'unavailable' || 'network-request-failed' || 'deadline-exceeded' => FailureKind.offline,
        'permission-denied' || 'unauthenticated' => FailureKind.notAllowed,
        'not-found' => FailureKind.notFound,
        'resource-exhausted' || 'too-many-requests' => FailureKind.limitReached,
        'requires-recent-login' => FailureKind.recentSignInNeeded,
        'invalid-argument' || 'failed-precondition' => FailureKind.invalid,
        _ => FailureKind.other,
      };

  @override
  String toString() => message;
}

/// Everything the app needs from a server. [FirebaseBackend] is the real one;
/// tests use a fake.
abstract class Backend {
  // Auth
  Stream<AuthUser?> get authChanges;

  /// Sends a code. Resolves to a verification id.
  Future<String> sendOtp(String e164Phone);
  Future<void> confirmOtp(String verificationId, String code);
  Future<void> signInWithGoogle();
  Future<void> refreshClaims();
  Future<void> signOut();
  Future<void> deleteAccount();

  // Account and draft
  Stream<AccountState> watchAccount(String uid);
  Stream<AppLimits> watchLimits();
  Future<Map<String, dynamic>?> loadDraft(String uid);
  Future<void> saveDraft(String uid, Map<String, dynamic> draft);
  Future<void> submitProfile();
  Future<String> uploadPhoto(String uid, String localPath);
  Future<String> photoUrl(String storagePath);
  Future<void> deletePhoto(String storagePath);

  // Discovery
  Future<IntroductionPage> fetchIntroductions(MatchFilters filters, int? cursor);
  Future<List<MatchProfile>> getProfiles(List<String> ids);
  Future<void> hideProfile(String target);

  // Proposals and contact
  Stream<List<Proposal>> watchProposals(String uid);
  Future<void> sendProposal(String to);
  Future<void> respondProposal(String from, {required bool accept});
  Future<void> withdrawProposal(String to);
  Stream<List<ContactRequestRecord>> watchContactRequests(String uid);
  Stream<Map<String, String>> watchSharedContacts(String uid);
  Future<void> requestContact(String to);
  Future<void> respondContact(String from, {required bool accept});

  // Matches and chat
  Stream<List<MatchThread>> watchMatches(String uid);
  Stream<List<ChatMessage>> watchMessages(String pairId, String uid);
  Future<void> sendMessage(String pairId, String uid, String text);
  Future<void> markThreadRead(String pairId, String uid);
  Future<void> unmatch(String other);
  Future<void> blockProfile(String target);
  Future<void> reportProfile(String target, String reason);
  Future<void> updatePrivacy({String? photoPrivacy, bool? showCaste, bool? allowFamilyShare});
  Future<void> touchActive();

  // Invites and edits
  Future<InviteInfo> getInviteCode();
  Future<void> submitEdits();

  // Family Circle
  Stream<FamilyState> watchFamily(String member);
  Future<String> createFamilyInvite();
  Future<void> joinFamily(String code, String name);
  Future<void> removeGuardian(String guardian, {String? member});
  Future<void> shareWithFamily(String profileId);
  Future<void> giveFamilyOpinion(String member, String profileId, String opinion);

  // Nikah Journey
  Future<void> setJourneyStep(String pairId, String uid, String step);
  Future<void> saveAnswers(String pairId, String uid, Map<String, String> answers);
  Future<Map<String, String>?> loadAnswers(String pairId, String uid);

  // Notifications
  Stream<List<NotificationItem>> watchNotifications(String uid);
  Future<void> markNotificationRead(String uid, String id);
  Future<void> registerPushToken(String uid);

  // Verification
  Stream<List<VerificationDoc>> watchDocuments(String uid);
  Future<void> submitDocument(String uid, String type, List<String> localPaths);

  // Purchases
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
    String? packageName,
  });

  // Review tools, reviewer accounts only
  Future<List<Map<String, dynamic>>> listReviewQueue();
  Future<List<String>> documentUrls(String uid, String type);
  Future<void> reviewProfile(String uid, {required bool approve, String reason});
  Future<void> reviewDocument(
    String uid,
    String type, {
    required bool approve,
    String reason,
  });
}

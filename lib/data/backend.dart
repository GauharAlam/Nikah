import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../models/notification_item.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';

/// Review progress of a member's profile. Owned by the server.
enum ReviewStage {
  draft,
  submitted,
  approved,
  changesRequested,
  rejected;

  static ReviewStage fromWire(Object? value) => switch (value) {
        'submitted' => submitted,
        'approved' => approved,
        'changes_requested' => changesRequested,
        'rejected' => rejected,
        _ => draft,
      };
}

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
    this.rejectedPhotos = const <String>[],
    this.editsPending = false,
    this.proposalsSentToday = 0,
    this.decisionsToday = 0,
    this.contactCreditsLeft = 0,
    this.premiumUntil,
    this.plan = '',
    this.familyOf,
    this.subjectOf,
    this.subjectCode = '',
    this.subjectConfirmed = false,
    this.paused = false,
  });

  final ReviewStage stage;
  final String rejectionReason;

  /// Photos a reviewer asked the member to replace.
  final List<String> rejectedPhotos;

  /// Published-profile edits waiting for review.
  final bool editsPending;
  final int proposalsSentToday;
  final int decisionsToday;

  /// Purchased credits minus credits spent this month. The monthly allowance
  /// comes from [AppLimits].
  final int contactCreditsLeft;
  final DateTime? premiumUntil;
  final String plan;

  /// The member whose circle this account belongs to, if any.
  final String? familyOf;

  /// The profile this person confirmed was made for them, if any.
  final String? subjectOf;

  /// For a family-made profile: the code the person enters on their own phone.
  final String subjectCode;
  final bool subjectConfirmed;
  final bool paused;

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
    this.theirReadAt,
  });

  final String pairId;
  final String otherId;
  final bool isOpen;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final String? myStep;
  final String? theirStep;

  /// When the other member last read this conversation.
  final DateTime? theirReadAt;
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

/// What a family member may do. Only permissions with a real feature behind them.
const Map<String, String> familyPermissionLabels = <String, String>{
  'view_shortlist': 'See profiles I share and give an opinion',
  'view_profile': 'See a summary of my profile',
  'view_proposals': 'See proposals I receive',
  'manage_proposals': 'Answer proposals for me',
};

const Map<String, String> familyRelationships = <String, String>{
  'father': 'Father',
  'mother': 'Mother',
  'brother': 'Brother',
  'sister': 'Sister',
  'uncle': 'Uncle',
  'aunt': 'Aunt',
  'guardian': 'Guardian',
  'other': 'Other',
};

class FamilyMember {
  const FamilyMember({
    required this.uid,
    required this.name,
    required this.relationship,
    required this.permissions,
  });
  final String uid;
  final String name;
  final String relationship;
  final List<String> permissions;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.name,
    required this.relationship,
    required this.status,
    this.expiresAt,
  });
  final String id;
  final String name;
  final String relationship;
  final String status;
  final DateTime? expiresAt;
  bool get isPending => status == 'pending';
}

class FamilyEvent {
  const FamilyEvent({required this.action, required this.at});
  final String action;
  final DateTime at;
}

/// The owner's view of their circle.
class FamilyAdmin {
  const FamilyAdmin({
    this.members = const <FamilyMember>[],
    this.invitations = const <FamilyInvitation>[],
    this.history = const <FamilyEvent>[],
  });
  final List<FamilyMember> members;
  final List<FamilyInvitation> invitations;
  final List<FamilyEvent> history;
}

class FamilyProposal {
  const FamilyProposal({required this.from, required this.summary});
  final String from;
  final String summary;
}

/// What the server lets this guardian see, decided per permission.
class FamilyOverview {
  const FamilyOverview({
    this.permissions = const <String>[],
    this.profileSummary,
    this.proposals,
  });
  final List<String> permissions;
  final String? profileSummary;
  final List<FamilyProposal>? proposals;
}

class BlockedMember {
  const BlockedMember(this.id, this.name);
  final String id;
  final String name;
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

  /// Sends a code. Resolves to a verification id, or null when the device
  /// verified the number by itself and no code is needed.
  Future<String?> sendOtp(String e164Phone);

  /// Signs in, or links the number when already signed in another way.
  Future<void> confirmOtp(String verificationId, String code);
  Future<void> signInWithGoogle();
  Future<void> refreshClaims();
  Future<void> signOut();

  /// Confirms the person's identity afresh is the caller's job: this fails with
  /// [FailureKind.recentSignInNeeded] on an old session.
  Future<void> deleteAccount();

  // Account and draft
  Stream<AccountState> watchAccount(String uid);
  Stream<AppLimits> watchLimits();
  Future<Map<String, dynamic>?> loadDraft(String uid);
  Future<void> saveDraft(String uid, Map<String, dynamic> draft);
  Future<void> submitProfile();
  Future<String> uploadPhoto(String uid, String localPath, {void Function(double)? onProgress});
  Future<String> photoUrl(String storagePath);
  Future<void> deletePhoto(String storagePath);

  // Discovery
  Future<IntroductionPage> fetchIntroductions(MatchFilters filters, int? cursor, {bool nearby = false});
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
  /// The newest messages of one conversation, live.
  Stream<List<ChatMessage>> watchMessages(String pairId, String uid);

  /// A page of messages older than [before], oldest first.
  Future<List<ChatMessage>> olderMessages(String pairId, String uid, DateTime before);

  /// [id] is chosen by the sender, so a retry can never send a message twice.
  Future<void> sendMessage(String pairId, String uid, String text, {required String id});
  Future<void> markThreadRead(String pairId, String uid);
  Future<void> unmatch(String other);
  Future<void> blockProfile(String target);
  Future<void> reportProfile(String target, String reason);
  Future<void> updatePrivacy({
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? nearbyOptIn,
    bool? allowContactRequests,
  });
  Future<void> touchActive();
  Future<void> setPaused(bool paused);
  Future<List<BlockedMember>> listBlocks();
  Future<void> unblockProfile(String target);
  Future<Map<String, dynamic>> exportMyData();

  // Invites and edits
  Future<InviteInfo> getInviteCode();
  Future<void> submitEdits();

  // Family Circle
  Stream<FamilyState> watchFamily(String member);
  Stream<FamilyAdmin> watchFamilyAdmin(String member);
  Future<String> createFamilyInvite({
    required String name,
    required String relationship,
    required String phone,
    required List<String> permissions,
  });
  Future<void> joinFamily(String code);
  Future<void> rejectFamilyInvite(String code);
  Future<void> cancelFamilyInvite(String id);
  Future<String> resendFamilyInvite(String id);
  Future<void> updateGuardianPermissions(String guardian, List<String> permissions);
  Future<FamilyOverview> familyOverview(String member);
  Future<void> familyRespondProposal(String member, String from, {required bool accept});
  Future<void> confirmSubject(String code, {required bool agree});
  Future<void> withdrawSubject();
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


  /// [decision] is `approve`, `changes` or `reject`. [version] is the
  /// submission the reviewer actually saw.
  Future<void> reviewProfile(
    String uid, {
    required String decision,
    required int version,
    String reason,
    List<String> rejectedPhotos,
  });

  /// [decision] is `approve`, `reject` or `resubmit`.
  Future<void> reviewDocument(
    String uid,
    String type, {
    required String decision,
    String reason,
  });
}

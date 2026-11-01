import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/backend.dart';
import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/meeting.dart';
import '../models/nikah_journey.dart';
import '../models/match_profile.dart';
import '../models/notification_item.dart';
import '../models/profile_report.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';
import '../models/ward_profile.dart';
import '../models/wali.dart';
import 'app_store.dart';

/// A local simulation of the whole app, for previews without Firebase and for
/// widget tests. Compiled out of release builds; see [AppConfig.mode].
/// Everything here stays on the device and nothing here is a real member.
class DemoAppStore extends AppStore {
  DemoAppStore(this._prefs) : super(_prefs) {
    _load();
  }

  /// True until the first auth state is known.
  @override
  bool get isRestoring => false;

  // ─── Directory ────────────────────────────────────────────────────────────
  /// Men see women and women see men. On a real backend the server applies this.
  @override
  List<MatchProfile> get directory => _viewerIsMale ? _demoWomen : _demoMen;

  static final List<MatchProfile> _demoWomen = <MatchProfile>[
    ...MatchProfile.femaleSeeds,
    ...MatchProfile.demoExtras('female'),
  ];
  static final List<MatchProfile> _demoMen = <MatchProfile>[
    ...MatchProfile.seeds,
    ...MatchProfile.demoExtras('male'),
  ];

  bool get _viewerIsMale =>
      (_profile?.hasGender ?? false) && _profile!.gender == Gender.male;

  /// The sample match in demo builds, always of the opposite gender.
  MatchProfile get _demoMatch => directory.first;
  @override
  MatchProfile profileById(String id) => MatchProfile.byId(id);

  // ─── Sign-in ──────────────────────────────────────────────────────────────
  @override
  bool get isSignedIn => _stage != AuthStage.guest;
  @override
  bool get isReviewer => false;
  @override
  ReviewStage get reviewStage =>
      _onboarded ? ReviewStage.approved : ReviewStage.draft;
  @override
  String get rejectionReason => '';

  static const String demoOtp = AppConfig.demoOtp;

  @override
  String get verifiedPhone => _profile?.phone ?? '';

  @override
  Future<String?> sendOtp(String e164Phone) async => e164Phone;

  @override
  Future<void> confirmOtp(String verificationId, String code) async {
    if (code != demoOtp) {
      throw const BackendException('That code is not correct.');
    }
    _startDemoSession();
    updateProfile((WardProfile p) => p.copyWith(
          phone: verificationId.replaceFirst(RegExp(r'^\+\d{1,2}'), ''),
        ));
  }

  @override
  Future<void> signInWithGoogle() async => _startDemoSession();

  void _startDemoSession() {
    if (_onboarded) {
      _stage = AuthStage.active;
      unawaited(_prefs.setString(_kStage, 'active'));
      notifyListeners();
    } else {
      enterOnboarding();
    }
  }

  // ─── Pledge ───────────────────────────────────────────────────────────────
  @override
  bool get pledgeAccepted => _prefs.getBool(_kPledge) ?? false;

  @override
  void acceptPledge() {
    unawaited(_prefs.setBool(_kPledge, true));
    notifyListeners();
  }

  // ─── Photos and profile submission ────────────────────────────────────────
  /// Returns what to store in the draft for a picked photo.
  @override
  Future<String> uploadPhoto(String localPath, {void Function(double)? onProgress}) async => localPath;

  /// Display location for a draft photo: a URL, or a local path in demo builds.
  @override
  Future<String> photoSource(String stored) async => stored;

  @override
  Future<void> removePhoto(String stored) async {
    updateProfile((WardProfile p) => p.copyWith(
          photos: p.photos.where((String x) => x != stored).toList(),
        ));
  }

  /// Saves the draft after each onboarding step.
  @override
  Future<void> saveDraft(WardProfile next) async {
    updateProfile((_) => next);
  }

  /// Demo builds have no reviewer, so a submission is approved at once.
  @override
  Future<void> submitProfile() async {
    submitOnboarding();
  }

  // ─── Invites, edits and family ────────────────────────────────────────────
  @override
  String get uid => 'demo';

  /// Demo builds have no server, so this code earns nothing.
  @override
  Future<InviteInfo> inviteInfo() async => const InviteInfo('DEMO24', 0, 0);

  /// Publishes profile edits. Demo builds have no review step.
  @override
  void submitEdits() {}

  FamilyState _family = const FamilyState();
  @override
  FamilyState get family => _family;

  /// The circle this account joined as a guardian, if any.
  @override
  FamilyState? get guardianView => null;
  @override
  bool get isGuardian => false;

  @override
  Future<String> createFamilyInvite({
    required String name,
    required String relationship,
    required String phone,
    required List<String> permissions,
  }) async =>
      'DEMO24';

  @override
  Future<void> joinFamily(String code) async {
    throw const BackendException('Family codes work once the app is connected.');
  }

  @override
  Future<void> removeGuardian(String guardian) async {}

  @override
  Future<void> shareWithFamily(String profileId) async {
    final MatchProfile p = profileById(profileId);
    if (_family.shortlist.any((FamilyPick x) => x.id == profileId)) return;
    _family = FamilyState(
      guardians: _family.guardians,
      shortlist: <FamilyPick>[
        ..._family.shortlist,
        FamilyPick(
          id: p.id,
          title: '${p.firstName}, ${p.age}',
          summary: <String>[p.education, p.profession, p.location]
              .where((String s) => s.isNotEmpty)
              .join(' · '),
        ),
      ],
    );
    notifyListeners();
  }

  @override
  void giveFamilyOpinion(String profileId, String opinion) {}

  // ─── Free profile limit ───────────────────────────────────────────────────
  static const String _kViewed = 'bk_viewed';
  static const int freeProfileLimit = 15;

  Set<String> get _viewed => _decodeSet(_prefs.getString(_kViewed));

  /// Free views left, or null for premium members.
  @override
  int? get freeProfilesLeft {
    if (isPremium) return null;
    final int left = freeProfileLimit - _viewed.length;
    return left < 0 ? 0 : left;
  }

  @override
  bool get reachedProfileLimit => freeProfilesLeft == 0;
  @override
  int get freeProfileAllowance => freeProfileLimit;

  /// Demo builds count a profile when it is first shown. Real builds count on
  /// the server when a profile is delivered.
  @override
  void markProfileViewed(String id) {
    final Set<String> viewed = _viewed;
    if (isPremium || viewed.contains(id) || viewed.length >= freeProfileLimit) return;
    unawaited(_prefs.setString(_kViewed, <String>{...viewed, id}.join(',')));
    notifyListeners();
  }

  // ─── Discovery paging ─────────────────────────────────────────────────────
  @override
  bool get isLoadingIntroductions => false;
  @override
  String? get introductionsError => null;
  @override
  Future<void> refreshIntroductions({bool keepDeck = false}) async {}
  @override
  Future<void> loadMoreIntroductions() async {}

  // ─── Contact ──────────────────────────────────────────────────────────────
  @override
  List<MatchProfile> get incomingContactRequests => const <MatchProfile>[];
  @override
  Future<void> respondContact(String matchId, {required bool accept}) async {}
  @override
  String sharedPhone(String matchId) => '';

  // ─── Limits ───────────────────────────────────────────────────────────────
  @override
  int get dailyProposalLimit => proposalQuota;
  @override
  int get monthlyCredits => monthlyContactCredits;
  @override
  int get decisionsPerDay => 10;
  @override
  int get pendingLimit => 15;
  @override
  bool get isPremium => false;
  @override
  bool get requireIdProof => true;
  @override
  bool get graduatesOnly => true;
  @override
  DateTime? get premiumUntil => null;

  /// Grants nothing locally: entitlements come from the server only.
  @override
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
  }) async {}

  // ─── Privacy ──────────────────────────────────────────────────────────────
  @override
  void updatePrivacy({
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? nearbyOptIn,
    bool? allowContactRequests,
  }) {
    updateProfile((WardProfile p) => p.copyWith(
          photoPrivacy: photoPrivacy,
          showCaste: showCaste,
          allowFamilyShare: allowFamilyShare,
          nearbyOptIn: nearbyOptIn,
          allowContactRequests: allowContactRequests,
        ));
  }

  // ─── Nikah Journey ────────────────────────────────────────────────────────
  @override
  JourneyStep journeyStep(String matchId) =>
      JourneyStep.values.asNameMap()[_prefs.getString('bk_journey_$matchId')] ??
      JourneyStep.talking;

  /// The other person's step, once they have set one.
  @override
  JourneyStep? theirJourneyStep(String matchId) => null;

  @override
  void setJourneyStep(String matchId, JourneyStep step) {
    unawaited(_prefs.setString('bk_journey_$matchId', step.name));
    notifyListeners();
  }

  @override
  Future<Map<String, String>> myAnswers(String matchId) async {
    final String? raw = _prefs.getString('bk_answers_$matchId');
    if (raw == null) return <String, String>{};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  /// Null until both sides have answered. Demo builds have nobody to answer.
  @override
  Future<Map<String, String>?> theirAnswers(String matchId) async => null;

  @override
  Future<void> saveAnswers(String matchId, Map<String, String> answers) async {
    await _prefs.setString('bk_answers_$matchId', jsonEncode(answers));
  }

  final SharedPreferences _prefs;
  final List<Timer> _timers = <Timer>[];
  int _seq = 0;

  String _nextId(String prefix) {
    _seq++;
    return '$prefix-$_seq-${DateTime.now().millisecondsSinceEpoch}';
  }

  // ─── Persistence keys ─────────────────────────────────────────────────────
  static const String _kStage = 'bk_stage';
  static const String _kOnboarded = 'bk_onboarded';
  static const String _kSteps = 'bk_steps';
  static const String _kProfile = 'bk_profile';
  static const String _kChats = 'bk_chats';
  static const String _kReadAt = 'bk_read_at';
  static const String _kLikes = 'bk_likes';
  static const String _kIntros = 'bk_intros';
  static const String _kApproved = 'bk_approved';
  static const String _kFilters = 'bk_filters';
  static const String _kGuardian = 'bk_guardian';
  static const String _kPrivacy = 'bk_privacy';
  static const String _kLogs = 'bk_logs';
  static const String _kMeetings = 'bk_meetings';
  static const String _kNotifications = 'bk_notifications';
  static const String _kSettings = 'bk_settings';
  static const String _kSkipped = 'bk_skipped';
  static const String _kProposals = 'bk_proposals';
  static const String _kProposalRecords = 'bk_proposal_records';
  static const String _kProposalDay = 'bk_proposal_day';
  static const String _kProposalCount = 'bk_proposal_count';
  static const String _kContactCredits = 'bk_contact_credits';
  static const String _kContactRequests = 'bk_contact_requests';
  static const String _kIncoming = 'bk_incoming_requests';
  static const String _kDocs = 'bk_docs';
  static const String _kSharedContacts = 'bk_shared_contacts';
  static const String _kUnmatched = 'bk_unmatched';
  static const String _kPledge = 'bk_pledge';
  static const String _kBlocked = 'bk_blocked';
  static const String _kReports = 'bk_reports';

  static const String _demoGuardianName = 'Khalid Al-Mansoor';

  // ─── Session ──────────────────────────────────────────────────────────────
  AuthStage _stage = AuthStage.guest;
  bool _onboarded = false;

  AuthStage get stage => _stage;
  @override
  bool get isLoggedIn => _stage == AuthStage.active;
  bool get isOnboarding => _stage == AuthStage.onboarding;
  bool get hasCompletedOnboarding => _onboarded;

  @override
  void enterOnboarding() {
    _stage = AuthStage.onboarding;
    unawaited(_prefs.setString(_kStage, 'onboarding'));
    notifyListeners();
  }

  @override
  void signOut() {
    _stage = AuthStage.guest;
    unawaited(_prefs.setString(_kStage, 'guest'));
    notifyListeners();
  }

  // ─── Onboarding steps (1 account · 2 practice · 3 wali · 4 biodata) ───────
  Map<int, bool> _steps = <int, bool>{};

  bool stepDone(int step) => _steps[step] ?? false;

  int get nextIncompleteStep {
    for (int s = 1; s <= 4; s++) {
      if (!stepDone(s)) return s;
    }
    return 4;
  }

  void markStepDone(int step) {
    _steps = <int, bool>{..._steps, step: true};
    unawaited(_prefs.setString(_kSteps, _serializeSteps(_steps)));
    notifyListeners();
  }

  static String _serializeSteps(Map<int, bool> steps) =>
      jsonEncode(steps.map((k, v) => MapEntry(k.toString(), v)));

  static Map<int, bool> _deserializeSteps(String? raw) {
    if (raw == null || raw.isEmpty) return <int, bool>{};
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <int, bool>{};
    return decoded
        .map<int, bool>((k, v) => MapEntry(int.tryParse(k) ?? 0, v == true));
  }

  // ─── Ward profile (draft + submitted) ─────────────────────────────────────
  WardProfile? _profile;
  @override
  WardProfile? get profile => _profile;
  bool get hasProfile => _profile != null;

  @override
  void updateProfile(WardProfile Function(WardProfile) mutate) {
    final WardProfile base = _profile ?? const WardProfile();
    final WardProfile next = mutate(base).copyWith(updatedAt: DateTime.now());
    _profile = next;
    unawaited(_prefs.setString(_kProfile, WardProfile.encode(next)));
    notifyListeners();
  }

  /// Opens the account in demo builds, where no reviewer exists.
  void submitOnboarding() {
    _profile = (_profile ?? const WardProfile()).copyWith(updatedAt: DateTime.now());
    _onboarded = true;
    _stage = AuthStage.active;
    unawaited(_prefs.setString(_kProfile, WardProfile.encode(_profile!)));
    unawaited(_prefs.setBool(_kOnboarded, true));
    unawaited(_prefs.setString(_kStage, 'active'));
    _alignDemoData();
    notifyListeners();
  }

  // ─── Matches: likes, intro requests, filters ──────────────────────────────
  Set<String> _likes = <String>{};
  Set<String> _intros = <String>{};
  Set<String> _approved = <String>{};
  MatchFilters _filters = const MatchFilters();

  bool isLiked(String matchId) => _likes.contains(matchId);
  bool isIntroRequested(String matchId) => _intros.contains(matchId);
  @override
  bool isApproved(String matchId) => _approved.contains(matchId);
  @override
  MatchFilters get filters => _filters;

  /// Cards still visible on the discovery deck (connected people leave it).
  @override
  List<MatchProfile> get discoveredProfiles {
    final Set<String> viewed = _viewed;
    int room = freeProfilesLeft ?? directory.length;
    return directory
        .where((p) => !_approved.contains(p.id))
        .where((p) => !_skipped.contains(p.id))
        .where((p) => !_blocked.contains(p.id))
        .where((p) => _filters.acceptsProfile(p))
        .where((p) {
          if (viewed.contains(p.id)) return true;
          if (room <= 0) return false;
          room--;
          return true;
        })
        .toList();
  }

  @override
  Future<IntroductionPage> searchProfiles({required String query, required bool nearby, int? cursor}) async {
    final String q = query.toLowerCase();
    final List<MatchProfile> hits = discoveredProfiles
        .where((MatchProfile p) => q.isEmpty || '${p.university} ${p.profession} ${p.location}'.toLowerCase().contains(q))
        .toList();
    return IntroductionPage(hits, null);
  }

  List<MatchProfile> get introRequests =>
      directory.where((p) => _intros.contains(p.id)).toList();

  List<MatchProfile> get connectedMatches =>
      directory.where((p) => _approved.contains(p.id)).toList();

  void toggleLike(String matchId) {
    if (_likes.contains(matchId)) {
      _likes = <String>{..._likes..remove(matchId)};
    } else {
      _likes = <String>{..._likes, matchId};
    }
    unawaited(_prefs.setString(_kLikes, _likes.toList(growable: false).join(',')));
    notifyListeners();
  }

  void requestIntro(String matchId) {
    if (_intros.contains(matchId)) return;
    final MatchProfile match = profileById(matchId);
    _intros = <String>{..._intros, matchId};
    unawaited(_prefs.setString(_kIntros, _intros.toList(growable: false).join(',')));
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Intro request sent',
      detail:
          'Interest expressed in ${match.firstName}. Awaiting Wali approval.',
      createdAt: DateTime.now(),
    ));
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.intro,
      title: 'Introduction request forwarded',
      body: '$_demoGuardianName was notified about your interest in '
          '${match.firstName}.',
      createdAt: DateTime.now(),
      deepLink: '/wali/hub',
    ));
    notifyListeners();
  }

  /// Opens the match after mutual acceptance. Private so that no screen can
  /// create a match directly; the conversation starts empty.
  void _openMatch(String matchId) {
    if (_approved.contains(matchId)) return;
    _approved = <String>{..._approved, matchId};
    unawaited(_prefs.setString(
        _kApproved, _approved.toList(growable: false).join(',')));
    final MatchProfile match = profileById(matchId);
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.milestone,
      title: 'New match',
      body: 'You and ${match.firstName} are matched. Chat is now open.',
      createdAt: DateTime.now(),
      deepLink: '/chat/${match.id}',
    ));
    notifyListeners();
  }

  @override
  void setFilters(MatchFilters next) {
    _filters = next;
    unawaited(_prefs.setString(
        _kFilters, jsonEncode(next.toJson())));
    notifyListeners();
  }

  // ─── Proposals · contact requests · credits ─────────────
  /// Daily heart («Send Proposal») quota shown as `x/5 PROPOSALS SENT`.
  static const int proposalQuota = 5;

  /// Monthly gold («Request Contact») credits included with the plan.
  static const int monthlyContactCredits = 30;

  /// One proposal per profile per direction. Replaces the former
  /// `_proposals` / `_incomingRequests` string sets (G-04).
  List<Proposal> _proposalRecords = <Proposal>[];
  Set<String> _skipped = <String>{};
  Set<String> _contactRequestsOut = <String>{};
  Set<String> _sharedContacts = <String>{};
  Set<String> _unmatched = <String>{};
  Set<String> _blocked = <String>{};
  List<ProfileReport> _reports = <ProfileReport>[];
  String _proposalDay = '';
  int _proposalCount = 0;
  int _contactCredits = monthlyContactCredits;
  List<VerificationDoc> _docs = List<VerificationDoc>.from(VerificationDoc.seeds);

  static String get _todayKey {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  @override
  int get proposalsSentToday =>
      _proposalDay == _todayKey ? _proposalCount : 0;
  @override
  int get proposalsLeft {
    final int left = dailyProposalLimit - proposalsSentToday;
    return left < 0 ? 0 : left;
  }

  // ─── Proposal lookups ─────────────────────────────────────────────────────

  /// The proposal for [matchId] in [direction], if one exists.
  Proposal? proposalFor(String matchId, ProposalDirection direction) {
    for (final Proposal p in _proposalRecords) {
      if (p.profileId == matchId && p.direction == direction) return p;
    }
    return null;
  }

  @override
  Proposal? outgoingProposal(String matchId) =>
      proposalFor(matchId, ProposalDirection.outgoing);

  @override
  Proposal? incomingProposal(String matchId) =>
      proposalFor(matchId, ProposalDirection.incoming);

  /// Whether this member has a live proposal out to [matchId]. A withdrawn or
  /// declined proposal is not live, so the heart becomes available again.
  @override
  bool hasProposed(String matchId) {
    final Proposal? p = outgoingProposal(matchId);
    return p != null &&
        (p.status == ProposalStatus.pending ||
            p.status == ProposalStatus.accepted);
  }

  bool hasSkipped(String matchId) => _skipped.contains(matchId);
  bool hasUnmatched(String matchId) => _unmatched.contains(matchId);
  @override
  bool contactRequested(String matchId) => _contactRequestsOut.contains(matchId);
  @override
  bool isContactShared(String matchId) => _sharedContacts.contains(matchId);

  /// «Chat Matches» deck — approved for chaperoned chat, contacts private.
  @override
  List<MatchProfile> get chatMatches => directory
      .where((p) => _approved.contains(p.id))
      .where((p) => !_sharedContacts.contains(p.id))
      .where((p) => !_unmatched.contains(p.id))
      .where((p) => !_blocked.contains(p.id))
      .toList();

  /// «Shared Contacts» deck — contact details exchanged.
  @override
  List<MatchProfile> get sharedContactProfiles => directory
      .where((p) => _sharedContacts.contains(p.id))
      .where((p) => !_unmatched.contains(p.id))
      .where((p) => !_blocked.contains(p.id))
      .toList();

  /// Proposals this member sent, newest first. A withdrawn proposal is
  /// dropped from the list; declined and expired stay visible as outcomes.
  @override
  List<Proposal> get sentProposals => (_proposalRecords
          .where((Proposal p) => p.isOutgoing)
          .where((Proposal p) => p.status != ProposalStatus.withdrawn)
          .where((Proposal p) => !_blocked.contains(p.profileId))
          .toList()
        ..sort((Proposal a, Proposal b) => b.createdAt.compareTo(a.createdAt)));

  /// Proposals awaiting this member's accept/decline, newest first.
  @override
  List<Proposal> get pendingIncomingProposals => (_proposalRecords
          .where((Proposal p) => p.isIncoming && p.isPending)
          .toList()
        ..sort((Proposal a, Proposal b) => b.createdAt.compareTo(a.createdAt)));

  List<MatchProfile> get proposalsSentList => sentProposals
      .map((Proposal p) => profileById(p.profileId))
      .toList();

  /// Profiles whose proposal is waiting on this member — what the Proposals
  /// «Received» tab lists.
  List<MatchProfile> get incomingProposalProfiles => pendingIncomingProposals
      .map((Proposal p) => profileById(p.profileId))
      .toList();

  @override
  int get pendingRequestCount => pendingIncomingProposals.length;

  @override
  int get contactCredits => _contactCredits;

  @override
  List<VerificationDoc> get verificationDocs =>
      List<VerificationDoc>.unmodifiable(_docs);

  @override
  bool get isVerifiedMember =>
      _docs.where((d) => d.isRequired).every(
            (d) => d.status == VerificationDocStatus.approved,
          );

  @override
  int get verificationProgress {
    final List<VerificationDoc> required =
        _docs.where((d) => d.isRequired).toList();
    if (required.isEmpty) return 0;
    final int done = required
        .where((d) => d.status == VerificationDocStatus.approved)
        .length;
    return (done * 100 / required.length).round();
  }

  void _saveState() {
    unawaited(_prefs.setString(
        _kSkipped, _skipped.toList(growable: false).join(',')));
    unawaited(_prefs.setString(
        _kProposalRecords, Proposal.encodeList(_proposalRecords)));
    unawaited(_prefs.setString(_kProposalDay, _proposalDay));
    unawaited(_prefs.setInt(_kProposalCount, _proposalCount));
    unawaited(_prefs.setInt(_kContactCredits, _contactCredits));
    unawaited(_prefs.setString(_kContactRequests,
        _contactRequestsOut.toList(growable: false).join(',')));
    unawaited(_prefs.setString(
        _kSharedContacts, _sharedContacts.toList(growable: false).join(',')));
    unawaited(_prefs.setString(
        _kUnmatched, _unmatched.toList(growable: false).join(',')));
    unawaited(_prefs.setString(
        _kBlocked, _blocked.toList(growable: false).join(',')));
    unawaited(
        _prefs.setString(_kReports, ProfileReport.encodeList(_reports)));
    unawaited(_prefs.setString(_kDocs, VerificationDoc.encodeList(_docs)));
  }

  /// Remove a match from the matches decks («Unmatch»).
  @override
  void unmatch(String matchId) {
    if (_unmatched.contains(matchId)) return;
    _unmatched = <String>{..._unmatched, matchId};
    _saveState();
    final MatchProfile match = profileById(matchId);
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Match removed',
      detail: 'The connection with ${match.firstName} was closed.',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  @override
  bool isBlocked(String matchId) => _blocked.contains(matchId);
  List<ProfileReport> get reports => List<ProfileReport>.unmodifiable(_reports);

  /// Hides [matchId] from every list on this device and closes the
  /// conversation. A pending proposal from them is declined.
  @override
  Future<void> blockProfile(String matchId) async {
    if (_blocked.contains(matchId)) return;
    _blocked = <String>{..._blocked, matchId};
    _transition(matchId, ProposalDirection.incoming, ProposalStatus.declined);
    _saveState();
    notifyListeners();
  }

  /// Keeps the report on this device. Nothing reaches a reviewer until the
  /// reporting backend exists, and the UI says so.
  @override
  Future<void> reportProfile(String matchId, String reason, {String details = '', String context = 'profile'}) async {
    _reports = <ProfileReport>[
      ..._reports,
      ProfileReport(
        profileId: matchId,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    ];
    _saveState();
    notifyListeners();
  }

  /// Skip a card («Incompatible»). The profile leaves the discovery deck.
  @override
  void markIncompatible(String matchId) {
    if (_skipped.contains(matchId)) return;
    _skipped = <String>{..._skipped, matchId};
    _saveState();
    notifyListeners();
  }

  /// Send a heart proposal using one of the daily slots.
  ///
  /// Returns `false` when the quota is exhausted. Re-sending to a profile that
  /// already has a live proposal is a no-op and does not spend a slot.
  ///
  /// Sending does NOT create a match: a match requires the recipient to accept
  /// (see [acceptProposal]).
  @override
  bool sendProposal(String matchId) {
    if (hasProposed(matchId)) return true;
    if (proposalsLeft == 0) return false;
    if (_proposalDay != _todayKey) {
      _proposalDay = _todayKey;
      _proposalCount = 0;
    }
    _proposalCount++;
    // Replace any prior terminal record for this direction, so history never
    // holds two outgoing proposals for the same profile.
    _proposalRecords = <Proposal>[
      ..._proposalRecords.where((Proposal p) =>
          !(p.profileId == matchId && p.isOutgoing)),
      Proposal(
        id: _nextId('prp'),
        profileId: matchId,
        direction: ProposalDirection.outgoing,
        status: ProposalStatus.pending,
        createdAt: DateTime.now(),
      ),
    ];
    _skipped = <String>{..._skipped..remove(matchId)};
    _saveState();
    final MatchProfile match = profileById(matchId);
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Proposal sent',
      detail: 'Your interest was shared with ${match.firstName}\'s family.',
      createdAt: DateTime.now(),
    ));
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.intro,
      title: 'Proposal sent',
      body: '$_demoGuardianName can see your proposal to ${match.firstName} '
          'in the Proposals tab.',
      createdAt: DateTime.now(),
      deepLink: '/home/matches',
    ));
    notifyListeners();
    return true;
  }

  /// Spend one gold credit to ask for the contact details.
  /// Returns `false` when credits are exhausted (buy more in Premium).
  @override
  bool requestContact(String matchId) {
    if (isContactShared(matchId) || _contactRequestsOut.contains(matchId)) {
      return true;
    }
    if (_contactCredits <= 0) return false;
    _contactCredits--;
    _contactRequestsOut = <String>{..._contactRequestsOut, matchId};
    _saveState();
    final MatchProfile match = profileById(matchId);
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Contact requested',
      detail: 'A gold credit was used to request '
          '${match.firstName}\'s contact details.',
      createdAt: DateTime.now(),
    ));
    // The request stays pending until the recipient actually accepts it.
    // Nothing on this device may accept on another member's behalf.
    notifyListeners();
    return true;
  }

  /// Records that contact details were exchanged with an existing match.
  /// Sharing never creates a match: refused unless they are already matched.
  bool acceptContact(String matchId) {
    if (!_approved.contains(matchId)) return false;
    _sharedContacts = <String>{..._sharedContacts, matchId};
    _saveState();
    notifyListeners();
    return true;
  }

  // ─── Proposal transitions ─────────────────────────────────────────────────

  /// Applies [next] to the proposal for [matchId] in [direction], enforcing
  /// [Proposal.canTransition] and [Proposal.isActorAllowed].
  ///
  /// Returns the updated proposal, or `null` when no such proposal exists or
  /// the transition is not permitted. The caller decides how to report that.
  Proposal? _transition(
    String matchId,
    ProposalDirection direction,
    ProposalStatus next,
  ) {
    final Proposal? current = proposalFor(matchId, direction);
    if (current == null) return null;
    final Proposal? updated = current.tryTransition(next);
    if (updated == null) return null;
    _proposalRecords = _proposalRecords
        .map((Proposal p) => p.id == updated.id ? updated : p)
        .toList();
    _saveState();
    return updated;
  }

  /// Accept a proposal someone sent to this member.
  ///
  /// The sender declared interest and the recipient has now accepted, so
  /// consent is mutual. [_openMatch] is private and this is its only caller.
  /// Returns `false` when there is no pending incoming proposal to accept.
  @override
  bool acceptProposal(String matchId) {
    final Proposal? updated = _transition(
      matchId,
      ProposalDirection.incoming,
      ProposalStatus.accepted,
    );
    if (updated == null) return false;

    final MatchProfile match = profileById(matchId);
    _openMatch(matchId);
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Proposal accepted',
      detail: 'You accepted ${match.firstName}\'s proposal — interest is '
          'mutual, so you are now matched.',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return true;
  }

  /// Decline a proposal someone sent to this member.
  @override
  bool declineProposal(String matchId) {
    final Proposal? updated = _transition(
      matchId,
      ProposalDirection.incoming,
      ProposalStatus.declined,
    );
    if (updated == null) return false;
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Proposal declined',
      detail: '${profileById(matchId).firstName}\'s proposal was '
          'declined. No match was created.',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return true;
  }

  /// Take back a proposal this member sent, before the other side replies.
  ///
  /// The spent daily slot is not refunded — the proposal was delivered.
  @override
  Future<bool> withdrawProposal(String matchId) async {
    final Proposal? updated = _transition(
      matchId,
      ProposalDirection.outgoing,
      ProposalStatus.withdrawn,
    );
    if (updated == null) return false;
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.intro,
      title: 'Proposal withdrawn',
      detail: 'Your proposal to ${profileById(matchId).firstName} was '
          'withdrawn.',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return true;
  }

  /// In demo builds the file goes nowhere, so the screen says so.
  @override
  Future<void> uploadVerificationDoc(
    String docId,
    List<String> localPaths,
  ) async =>
      submitVerificationDoc(docId);

  /// Demo upload — moves a document from missing to under review.
  void submitVerificationDoc(String docId) {
    _docs = _docs
        .map((d) => d.id == docId && d.status == VerificationDocStatus.missing
            ? d.copyWith(status: VerificationDocStatus.pending)
            : d)
        .toList();
    _saveState();
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.system,
      title: 'Document under review',
      body: 'Our team is reviewing the document you uploaded.',
      createdAt: DateTime.now(),
      deepLink: '/profile/verify',
    ));
    notifyListeners();
  }

  // ─── Chats ────────────────────────────────────────────────────────────────
  Map<String, List<ChatMessage>> _chats = <String, List<ChatMessage>>{};
  Map<String, DateTime> _readAt = <String, DateTime>{};

  @override
  List<String> get chatThreadIds {
    final Iterable<String> visible = _chats.keys.where((String id) =>
        !_blocked.contains(id) && _chats[id]!.isNotEmpty);
    final Map<String, DateTime> lastByThread = <String, DateTime>{
      for (final String id in visible)
        id: _chats[id]!.last.createdAt,
    };
    final List<String> sorted = visible.toList()
      ..sort((a, b) =>
          (lastByThread[b] ?? DateTime(0)).compareTo(lastByThread[a] ?? DateTime(0)));
    return sorted;
  }

  @override
  List<ChatMessage> messages(String matchId) =>
      List<ChatMessage>.unmodifiable(_chats[matchId] ?? const <ChatMessage>[]);

  @override
  String lastMessagePreview(String matchId) {
    final List<ChatMessage> thread = _chats[matchId] ?? const <ChatMessage>[];
    if (thread.isEmpty) return 'Say salam to begin chaperoned conversation';
    return thread.last.text;
  }

  @override
  int unreadCount(String matchId) {
    final DateTime? read = _readAt[matchId];
    final List<ChatMessage> thread = _chats[matchId] ?? const <ChatMessage>[];
    return thread
        .where((m) => m.sender == MessageSender.match)
        .where((m) => read == null || m.createdAt.isAfter(read))
        .length;
  }

  @override
  int get totalUnread => _chats.keys.fold(
      0, (int sum, String id) => sum + unreadCount(id));

  void seedThreadIfEmpty(String matchId) {
    if (_chats.containsKey(matchId)) return;
    final DateTime base = DateTime.now();
    final List<ChatMessage> seed = <ChatMessage>[
      ChatMessage(
        id: _nextId('msg'),
        text: 'As-salamu alaykum wa rahmatullahi wa barakatuh. Thank you for '
            'the introduction through your esteemed Wali.',
        time: _fmtTime(base.subtract(const Duration(minutes: 6))),
        createdAt: base.subtract(const Duration(minutes: 6)),
        sender: MessageSender.match,
      ),
      ChatMessage(
        id: _nextId('msg'),
        text: 'Chaperone: This sample conversation shows how a guardian note appears.',
        time: _fmtTime(base.subtract(const Duration(minutes: 5))),
        createdAt: base.subtract(const Duration(minutes: 5)),
        sender: MessageSender.chaperone,
      ),
      ChatMessage(
        id: _nextId('msg'),
        text:
            'Wa alaykum as-salam, wa barakatuh. My father reviewed your '
            'biodata and we would love to proceed, in sha Allah.',
        time: _fmtTime(base.subtract(const Duration(minutes: 4))),
        createdAt: base.subtract(const Duration(minutes: 4)),
        sender: MessageSender.user,
      ),
      ChatMessage(
        id: _nextId('msg'),
        text: 'MashaAllah, alhamdulillah. My Wali suggests a family video '
            'call this Saturday. Would that suit your guardian?',
        time: _fmtTime(base.subtract(const Duration(minutes: 2))),
        createdAt: base.subtract(const Duration(minutes: 2)),
        sender: MessageSender.match,
      ),
    ];
    _chats = <String, List<ChatMessage>>{..._chats, matchId: seed};
    _readAt = <String, DateTime>{
      ..._readAt,
      matchId: base.subtract(const Duration(minutes: 3)),
    };
    _saveChats();
    _saveReadAt();
    notifyListeners();
  }

  @override
  void markThreadRead(String matchId) {
    _readAt = <String, DateTime>{..._readAt, matchId: DateTime.now()};
    _saveReadAt();
    notifyListeners();
  }

  @override
  void sendMessage(String matchId, String text) {
    if (text.trim().isEmpty || _blocked.contains(matchId)) return;
    final DateTime now = DateTime.now();
    final ChatMessage userMsg = ChatMessage(
      id: _nextId('msg'),
      text: text.trim(),
      time: _fmtTime(now),
      createdAt: now,
      sender: MessageSender.user,
    );
    _chats = <String, List<ChatMessage>>{
      ..._chats,
      matchId: <ChatMessage>[..._chats[matchId] ?? const <ChatMessage>[], userMsg],
    };
    _saveChats();
    notifyListeners();
    // Incoming messages arrive from the messaging backend, not from a local
    // timer. Until that transport exists, a sent message simply stays sent.
  }

  // ─── Meeting requests ─────────────────────────────────────────────────────
  List<MeetingRequest> _meetings = <MeetingRequest>[];
  @override
  List<MeetingRequest> get meetings =>
      List<MeetingRequest>.unmodifiable(_meetings.reversed);

  @override
  MeetingRequest? get nextMeeting {
    final List<MeetingRequest> future = _meetings
        .where((m) => m.status == MeetingStatus.scheduled)
        .where((m) => m.scheduledAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return future.isEmpty ? null : future.first;
  }

  @override
  void scheduleMeeting(MeetingRequest request) {
    _meetings = <MeetingRequest>[..._meetings, request];
    unawaited(_prefs.setString(_kMeetings, MeetingRequest.encodeList(_meetings)));
    final MatchProfile match = request.match;
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.meeting,
      title: 'Family meeting scheduled',
      detail:
          '${request.format.label} with ${match.firstName} on '
          '${fmtDate(request.scheduledAt)} at ${_fmtTime(request.scheduledAt)}.',
      createdAt: DateTime.now(),
    ));
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.milestone,
      title: 'Meeting request sent',
      body: 'Your ${request.format.label} with ${match.firstName} is set for '
          '${fmtDate(request.scheduledAt)}.',
      createdAt: DateTime.now(),
      deepLink: '/home/matches',
    ));
    notifyListeners();
  }

  // ─── Guardian (Wali) state ────────────────────────────────────────────────
  Guardian _guardian = Guardian.seed;
  @override
  Guardian get guardian => _guardian;

  List<String> _privacyKeys = const <String>[
    'blurPhotos',
    'readReceipts',
    'activityAlerts',
    'chatChaperone',
    'shareWithWaliOnly',
  ];
  @override
  bool privacy(String key) => _privacyKeys.contains(key);

  List<ActivityLogEntry> _logs = <ActivityLogEntry>[];
  @override
  List<ActivityLogEntry> get activityLog =>
      List<ActivityLogEntry>.unmodifiable(_logs.reversed);

  @override
  void updateGuardian(Guardian next) {
    _guardian = next;
    unawaited(_prefs.setString(_kGuardian, Guardian.encode(next)));
    _profile = (_profile ?? WardProfile.demoWard).copyWith(
      guardian: next,
      waliVerified: next.isVerified,
      updatedAt: DateTime.now(),
    );
    unawaited(
        _prefs.setString(_kProfile, WardProfile.encode(_profile!)));
    markStepDone(3);
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.verification,
      title: 'Wali invitation sent',
      detail:
          'SMS invite dispatched to ${next.name} (${next.relation.label}).',
      createdAt: DateTime.now(),
    ));
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.wali,
      title: 'Wali invitation sent',
      body: 'A 6-digit verification code was texted to ${next.phoneCode} '
          '${next.phone}.',
      createdAt: DateTime.now(),
      deepLink: '/wali/portal',
    ));
    notifyListeners();
  }

  @override
  void verifyGuardianSms() {
    _guardian = _guardian.copyWith(isVerified: true);
    unawaited(_prefs.setString(_kGuardian, Guardian.encode(_guardian)));
    _profile = (_profile ?? WardProfile.demoWard).copyWith(
      guardian: _guardian,
      waliVerified: true,
      updatedAt: DateTime.now(),
    );
    unawaited(
        _prefs.setString(_kProfile, WardProfile.encode(_profile!)));
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.verification,
      title: 'Wali verified via SMS',
      detail: '$_demoGuardianName authenticated with the 6-digit portal '
          'passcode.',
      createdAt: DateTime.now(),
    ));
    _addNotification(NotificationItem(
      id: _nextId('ntf'),
      type: NotificationType.wali,
      title: 'Guardian verified',
      body: '$_demoGuardianName completed SMS verification successfully.',
      createdAt: DateTime.now(),
      deepLink: '/wali/hub',
    ));
    notifyListeners();
  }

  @override
  void setOnboardingGuardian(Guardian next) {
    _guardian = next;
    unawaited(_prefs.setString(_kGuardian, Guardian.encode(next)));
  }

  @override
  void togglePrivacy(String key, bool value) {
    final Set<String> next = <String>{..._privacyKeys};
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    _privacyKeys = next.toList(growable: false);
    unawaited(_prefs.setString(_kPrivacy, jsonEncode(_privacyKeys)));
    _addLog(ActivityLogEntry(
      id: _nextId('log'),
      kind: ActivityKind.general,
      title: 'Privacy setting updated',
      detail: '${AppStore.privacyLabel(key)} set to ${value ? 'ON' : 'OFF'}.',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void _addLog(ActivityLogEntry entry) {
    _logs = <ActivityLogEntry>[..._logs, entry].take(60).toList();
    unawaited(_prefs.setString(_kLogs, ActivityLogEntry.encodeList(_logs)));
  }

  // ─── Notifications ────────────────────────────────────────────────────────
  List<NotificationItem> _notifications = <NotificationItem>[];
  @override
  List<NotificationItem> get notifications =>
      List<NotificationItem>.unmodifiable(_notifications.reversed);
  @override
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void _addNotification(NotificationItem item) {
    _notifications = <NotificationItem>[..._notifications, item];
    if (_notifications.length > 40) {
      _notifications = _notifications.sublist(_notifications.length - 40);
    }
    unawaited(_prefs.setString(
        _kNotifications, NotificationItem.encodeList(_notifications)));
  }

  @override
  void markNotificationRead(String id) {
    if (_notifications.every((n) => n.isRead || n.id != id)) return;
    _notifications =
        _notifications.map((n) => n.id == id ? n.markRead() : n).toList();
    unawaited(_prefs.setString(
        _kNotifications, NotificationItem.encodeList(_notifications)));
    notifyListeners();
  }

  @override
  void markAllNotificationsRead() {
    if (_notifications.every((n) => n.isRead)) return;
    _notifications = _notifications.map((n) => n.markRead()).toList();
    unawaited(_prefs.setString(
        _kNotifications, NotificationItem.encodeList(_notifications)));
    notifyListeners();
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  bool _pushEnabled = true;
  bool _emailDigest = false;
  bool _showArabic = true;
  @override
  bool get pushEnabled => _pushEnabled;
  @override
  bool get emailDigest => _emailDigest;
  @override
  bool get showArabic => _showArabic;

  @override
  void setPushEnabled(bool value) {
    _pushEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  @override
  void setEmailDigest(bool value) {
    _emailDigest = value;
    _saveSettings();
    notifyListeners();
  }

  @override
  void setShowArabic(bool value) {
    _showArabic = value;
    _saveSettings();
    notifyListeners();
  }

  void _saveSettings() {
    unawaited(_prefs.setString(
      _kSettings,
      jsonEncode(<String, dynamic>{
        'push': _pushEnabled,
        'email': _emailDigest,
        'arabic': _showArabic,
      }),
    ));
  }

  // ─── Load / persist ───────────────────────────────────────────────────────
  void _load() {
    _stage = switch (_prefs.getString(_kStage)) {
      'onboarding' => AuthStage.onboarding,
      'active' => AuthStage.active,
      _ => AuthStage.guest,
    };
    _onboarded = _prefs.getBool(_kOnboarded) ?? false;
    _profile = WardProfile.decode(_prefs.getString(_kProfile));
    _steps = _deserializeSteps(_prefs.getString(_kSteps));
    _readAt = _decodeReadAt(_prefs.getString(_kReadAt));

    _chats = _decodeChatMap(_prefs.getString(_kChats));
    _likes = _decodeSet(_prefs.getString(_kLikes));
    _intros = _decodeSet(_prefs.getString(_kIntros));
    _approved = _decodeSet(_prefs.getString(_kApproved));

    _skipped = _decodeSet(_prefs.getString(_kSkipped));
    _proposalRecords = _loadProposalRecords();
    _contactRequestsOut = _decodeSet(_prefs.getString(_kContactRequests));
    _sharedContacts = _decodeSet(_prefs.getString(_kSharedContacts));
    _unmatched = _decodeSet(_prefs.getString(_kUnmatched));
    _blocked = _decodeSet(_prefs.getString(_kBlocked));
    _reports = ProfileReport.decodeList(_prefs.getString(_kReports));
    _proposalDay = _prefs.getString(_kProposalDay) ?? '';
    _proposalCount = _prefs.getInt(_kProposalCount) ?? 0;
    _contactCredits =
        _prefs.getInt(_kContactCredits) ?? monthlyContactCredits;
    _docs = VerificationDoc.decodeList(_prefs.getString(_kDocs));

    final String? filtersRaw = _prefs.getString(_kFilters);
    if (filtersRaw != null) {
      final dynamic decoded = jsonDecode(filtersRaw);
      if (decoded is Map<String, dynamic>) _filters = MatchFilters.fromJson(decoded);
    }

    _guardian =
        Guardian.decode(_prefs.getString(_kGuardian)) ?? Guardian.seed;
    _meetings = MeetingRequest.decodeList(_prefs.getString(_kMeetings) ?? '[]');
    _logs = _decodeLogs(_prefs.getString(_kLogs));
    _notifications =
        _decodeNotifications(_prefs.getString(_kNotifications));

    final String? privacyRaw = _prefs.getString(_kPrivacy);
    if (privacyRaw != null) {
      final dynamic decoded = jsonDecode(privacyRaw);
      if (decoded is List) {
        _privacyKeys = decoded.cast<String>().toList(growable: false);
      }
    }
    final String? settingsRaw = _prefs.getString(_kSettings);
    if (settingsRaw != null) {
      final dynamic decoded = jsonDecode(settingsRaw);
      if (decoded is Map<String, dynamic>) {
        _pushEnabled = decoded['push'] as bool? ?? true;
        _emailDigest = decoded['email'] as bool? ?? false;
        _showArabic = decoded['arabic'] as bool? ?? true;
      }
    }

    if (_logs.isEmpty) _seedLogs();
    if (_notifications.isEmpty) _seedNotifications();
    if (_meetings.isEmpty) _seedMeeting();
    _alignDemoData();
  }

  /// Keeps sample data on the opposite gender, including after a member's
  /// gender is first set or an older install is reopened.
  void _alignDemoData() {
    final Set<String> allowed = directory.map((MatchProfile p) => p.id).toSet();
    bool foreign(String id) =>
        !allowed.contains(id) && MatchProfile.byId(id).id == id;
    final bool stale = _approved.any(foreign) ||
        _chats.keys.any(foreign) ||
        _proposalRecords.any((Proposal p) => foreign(p.profileId));
    if (stale) {
      _approved = _approved.where((String id) => !foreign(id)).toSet();
      _intros = _intros.where((String id) => !foreign(id)).toSet();
      _likes = _likes.where((String id) => !foreign(id)).toSet();
      _skipped = _skipped.where((String id) => !foreign(id)).toSet();
      _chats = <String, List<ChatMessage>>{
        for (final String id in _chats.keys)
          if (!foreign(id)) id: _chats[id]!,
      };
      _proposalRecords = _proposalRecords
          .where((Proposal p) => !foreign(p.profileId))
          .toList();
      _seedLogs();
      _seedNotifications();
      _seedMeeting();
      _saveChats();
      _saveState();
    }
    if (!_onboarded && _stage != AuthStage.active) return;
    if (_chats.isEmpty) {
      seedThreadIfEmpty(_demoMatch.id);
      _approved = <String>{..._approved, _demoMatch.id};
    }
    if (_intros.isEmpty) _intros = <String>{_demoMatch.id};
    unawaited(_prefs.setString(_kApproved, _approved.toList(growable: false).join(',')));
    unawaited(_prefs.setString(_kIntros, _intros.toList(growable: false).join(',')));
    _seedDemoIncomingProposals();
  }

  /// Demo data: two members have proposed to this persona, so the Proposals
  /// «Received» tab and the accept/decline path are reachable offline.
  ///
  /// These records are local demo seeds, exactly like [MatchProfile.seeds].
  /// Real inbound proposals will come from the backend (Stage 6).
  void _seedDemoIncomingProposals() {
    if (!_onboarded && _stage != AuthStage.active) return;
    if (_proposalRecords.any((Proposal p) => p.isIncoming)) return;
    final DateTime now = DateTime.now();
    _proposalRecords = <Proposal>[
      ..._proposalRecords,
      Proposal(
        id: _nextId('prp'),
        profileId: directory[1].id,
        direction: ProposalDirection.incoming,
        status: ProposalStatus.pending,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      Proposal(
        id: _nextId('prp'),
        profileId: directory[4].id,
        direction: ProposalDirection.incoming,
        status: ProposalStatus.pending,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
    ];
    unawaited(_prefs.setString(
        _kProposalRecords, Proposal.encodeList(_proposalRecords)));
  }

  static Map<String, List<ChatMessage>> _decodeChatMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, List<ChatMessage>>{};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, List<ChatMessage>>{};
      }
      return decoded.map<String, List<ChatMessage>>(
        (String key, dynamic value) => MapEntry<String, List<ChatMessage>>(
          key,
          _decodeThread(value),
        ),
      );
    } catch (_) {
      // A corrupt or outdated blob must never brick app start-up: `_load`
      // runs from the constructor, so anything thrown here takes the app
      // down before the first frame.
      return <String, List<ChatMessage>>{};
    }
  }

  /// Decodes one stored thread.
  ///
  /// Accepts both the correct JSON array and the legacy double-encoded string
  /// written by earlier builds, so existing installs keep their history.
  static List<ChatMessage> _decodeThread(dynamic value) {
    final dynamic list = value is String ? jsonDecode(value) : value;
    if (list is! List) return const <ChatMessage>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  void _saveChats() {
    // Each thread is stored as a real JSON array. Writing
    // `ChatMessage.encodeList` here would nest an already-encoded *string*
    // inside the map, which `_decodeChatMap` could not read back.
    final Map<String, dynamic> encoded = <String, dynamic>{
      for (final String id in _chats.keys)
        id: _chats[id]!.map((ChatMessage m) => m.toJson()).toList(),
    };
    unawaited(_prefs.setString(_kChats, jsonEncode(encoded)));
  }

  static Map<String, DateTime> _decodeReadAt(String? raw) {
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <String, DateTime>{};
    return decoded.map<String, DateTime>(
      (String key, dynamic value) => MapEntry<String, DateTime>(
        key,
        DateTime.fromMillisecondsSinceEpoch(
            value is int ? value : int.tryParse('$value') ?? 0),
      ),
    );
  }

  void _saveReadAt() {
    unawaited(_prefs.setString(
      _kReadAt,
      jsonEncode(<String, dynamic>{
        for (final String id in _readAt.keys)
          id: _readAt[id]!.millisecondsSinceEpoch,
      }),
    ));
  }

  /// Reads the typed proposal records, migrating the legacy
  /// comma-separated `bk_proposals` key written by earlier builds.
  List<Proposal> _loadProposalRecords() {
    final List<Proposal> stored =
        Proposal.decodeList(_prefs.getString(_kProposalRecords));
    if (stored.isNotEmpty) return stored;

    final Set<String> legacy = _decodeSet(_prefs.getString(_kProposals));
    if (legacy.isEmpty) return <Proposal>[];
    // Legacy entries recorded only that a proposal had been sent.
    final DateTime now = DateTime.now();
    final List<Proposal> migrated = <Proposal>[
      for (final String id in legacy)
        Proposal(
          id: _nextId('prp'),
          profileId: id,
          direction: ProposalDirection.outgoing,
          status: ProposalStatus.pending,
          createdAt: now,
        ),
    ];
    unawaited(
        _prefs.setString(_kProposalRecords, Proposal.encodeList(migrated)));
    unawaited(_prefs.remove(_kProposals));
    return migrated;
  }

  static Set<String> _decodeSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    // These sets are written with `join(',')`, so `jsonDecode` would throw a
    // FormatException on real stored data. `_load` runs from the constructor,
    // which means anything thrown here crashes the app before its first
    // frame. Accept the comma form, tolerate a JSON array, never throw.
    final String trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded.whereType<String>().toSet();
      } catch (_) {
        // Fall through to the comma parser.
      }
    }
    return trimmed
        .split(',')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toSet();
  }

  static List<ActivityLogEntry> _decodeLogs(String? raw) {
    if (raw == null || raw.isEmpty) return <ActivityLogEntry>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <ActivityLogEntry>[];
      return decoded
          .cast<Map<String, dynamic>>()
          .map(ActivityLogEntry.fromJson)
          .toList();
    } catch (_) {
      return <ActivityLogEntry>[];
    }
  }

  static List<NotificationItem> _decodeNotifications(String? raw) {
    if (raw == null || raw.isEmpty) return <NotificationItem>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <NotificationItem>[];
      return decoded
          .cast<Map<String, dynamic>>()
          .map(NotificationItem.fromJson)
          .toList();
    } catch (_) {
      return <NotificationItem>[];
    }
  }

  void _seedLogs() {
    _logs = <ActivityLogEntry>[
      ActivityLogEntry(
        id: _nextId('log'),
        kind: ActivityKind.verification,
        title: 'Guardian verified',
        detail: '$_demoGuardianName completed SMS verification for this '
            'account.',
        createdAt: DateTime.now().subtract(const Duration(hours: 26)),
      ),
      ActivityLogEntry(
        id: _nextId('log'),
        kind: ActivityKind.intro,
        title: 'Intro approved — Ta\'aruf open',
        detail:
            '${_demoMatch.waliName} confirmed mutual intent; chaperoned '
            'chat with ${_demoMatch.firstName} unlocked.',
        createdAt: DateTime.now().subtract(const Duration(hours: 21)),
      ),
      ActivityLogEntry(
        id: _nextId('log'),
        kind: ActivityKind.chat,
        title: 'Chat audit complete',
        detail:
            '4 messages reviewed by your guardian — no concerns detected.',
        createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
    ];
    unawaited(_prefs.setString(_kLogs, ActivityLogEntry.encodeList(_logs)));
  }

  void _seedNotifications() {
    _notifications = <NotificationItem>[
      NotificationItem(
        id: _nextId('ntf'),
        type: NotificationType.match,
        title: 'New match recommended',
        body:
            'A wali-verified profile in Manchester fits your preferences well.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        deepLink: '/match/${directory[2].id}',
      ),
      NotificationItem(
        id: _nextId('ntf'),
        type: NotificationType.chat,
        title: '${_demoMatch.firstName} sent a message',
        body: 'Open the chaperoned thread within guardian supervision.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        deepLink: '/chat/${_demoMatch.id}',
      ),
      NotificationItem(
        id: _nextId('ntf'),
        type: NotificationType.wali,
        title: 'Wali digest ready',
        body:
            '$_demoGuardianName reviewed 4 messages and approved the '
            'Saturday family call.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        deepLink: '/wali/hub',
      ),
      NotificationItem(
        id: _nextId('ntf'),
        type: NotificationType.milestone,
        title: 'Upcoming chaperoned call',
        body:
            'Virtual family call with ${_demoMatch.firstName} on '
            '${fmtDate(DateTime.now().add(const Duration(days: 3)))} at 6:30 PM.',
        createdAt: DateTime.now().subtract(const Duration(hours: 26)),
        isRead: true,
        deepLink: '/home/matches',
      ),
      NotificationItem(
        id: _nextId('ntf'),
        type: NotificationType.system,
        title: 'Welcome to Nikah',
        body: 'Your guardianship-supervised space for sincere intentions. '
            'May Allah grant you a blessed union.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
    unawaited(_prefs.setString(
        _kNotifications, NotificationItem.encodeList(_notifications)));
  }

  void _seedMeeting() {
    _meetings = <MeetingRequest>[
      MeetingRequest(
        id: _nextId('mtg'),
        matchId: _demoMatch.id,
        format: MeetingFormat.video,
        scheduledAt: DateTime.now()
            .add(const Duration(days: 3))
            .copyWith(hour: 18, minute: 30),
        location: 'Family video bridge — link shared with both Wali',
        status: MeetingStatus.scheduled,
      ),
    ];
    unawaited(_prefs.setString(_kMeetings, MeetingRequest.encodeList(_meetings)));
  }

  @override
  Future<void> deleteAccount() async => resetAll();

  @override
  Future<String> exportData() async => '{}';

  void resetAll() {
    for (final String key in <String>[
      _kStage, _kOnboarded, _kSteps, _kProfile, _kChats, _kReadAt,
      _kLikes, _kIntros, _kApproved, _kFilters, _kGuardian, _kPrivacy,
      _kLogs, _kMeetings, _kNotifications, _kSettings, _kSkipped,
      _kProposals, _kProposalDay, _kProposalCount, _kContactCredits,
      _kContactRequests, _kIncoming, _kDocs, _kSharedContacts, _kUnmatched,
      _kProposalRecords, _kBlocked, _kReports, _kPledge, _kViewed,
    ]) {
      unawaited(_prefs.remove(key));
    }
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _stage = AuthStage.guest;
    _onboarded = false;
    _profile = null;
    _steps = <int, bool>{};
    _chats = <String, List<ChatMessage>>{};
    _readAt = <String, DateTime>{};
    _likes = <String>{};
    _intros = <String>{};
    _approved = <String>{};
    _filters = const MatchFilters();
    _guardian = Guardian.seed;
    _meetings = <MeetingRequest>[];
    _logs = <ActivityLogEntry>[];
    _notifications = <NotificationItem>[];
    _skipped = <String>{};
    _proposalRecords = <Proposal>[];
    _contactRequestsOut = <String>{};
    _sharedContacts = <String>{};
    _unmatched = <String>{};
    _blocked = <String>{};
    _reports = <ProfileReport>[];
    _proposalDay = '';
    _proposalCount = 0;
    _contactCredits = monthlyContactCredits;
    _docs = List<VerificationDoc>.from(VerificationDoc.seeds);
    _seedLogs();
    _seedNotifications();
    _seedMeeting();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  static String _fmtTime(DateTime dt) => AppStore.fmtTime(dt);
  static String fmtDate(DateTime dt) => AppStore.fmtDate(dt);
}

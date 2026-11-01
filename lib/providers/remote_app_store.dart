part of 'app_store.dart';

/// [AppStore] backed by a [Backend]. Screens keep their synchronous reads;
/// mutations are sent to the server and the result returns through the live
/// streams, so the server stays the only source of truth.
class RemoteAppStore extends AppStore {
  RemoteAppStore(super.prefs, this._backend) {
    _loadFilters();
    _authSub = _backend.authChanges.listen(_onAuth, onError: _report);
  }

  final Backend _backend;
  StreamSubscription<AuthUser?>? _authSub;
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  final Map<String, StreamSubscription<List<ChatMessage>>> _threadSubs =
      <String, StreamSubscription<List<ChatMessage>>>{};

  AuthUser? _user;
  bool _restoring = true;
  AccountState _account = const AccountState();
  AppLimits _limits = const AppLimits();
  Map<String, MatchThread> _threads = <String, MatchThread>{};
  Map<String, String> _phones = <String, String>{};
  List<ContactRequestRecord> _contactRecords = <ContactRequestRecord>[];
  final Map<String, MatchProfile> _cache = <String, MatchProfile>{};
  final Set<String> _fetching = <String>{};

  List<MatchProfile> _introductions = <MatchProfile>[];
  int? _cursor;
  bool _exhausted = false;
  bool _loadingIntros = false;
  String? _introError;

  @override
  Backend? get backend => _backend;
  @override
  bool get usesLocalState => false;
  @override
  bool get isRestoring => _restoring;
  @override
  bool get isReviewer => _user?.isReviewer ?? false;
  @override
  ReviewStage get reviewStage => _account.stage;
  @override
  String get rejectionReason => _account.rejectionReason;
  @override
  int get dailyProposalLimit => _limits.proposalsPerDay;
  @override
  int get monthlyCredits => _limits.monthlyContactCredits;
  @override
  int get decisionsPerDay => _limits.decisionsPerDay;
  @override
  int get pendingLimit => _limits.pendingLimit;
  @override
  bool get isPremium => _account.isPremium;
  @override
  DateTime? get premiumUntil => _account.premiumUntil;
  @override
  int get proposalsSentToday => _account.proposalsSentToday;
  @override
  int get proposalsLeft {
    if (isPremium) return 1 << 30;
    final int left = dailyProposalLimit - proposalsSentToday;
    return left < 0 ? 0 : left;
  }

  @override
  int get contactCredits {
    final int left = monthlyCredits + _account.contactCreditsLeft;
    return left < 0 ? 0 : left;
  }

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

  void _loadFilters() {
    final String? raw = _prefs.getString(AppStore._kFilters);
    if (raw == null) return;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) _filters = AppStore._decodeFilters(decoded);
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  Future<void> _closeSession() async {
    for (final StreamSubscription<dynamic> s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final StreamSubscription<List<ChatMessage>> s in _threadSubs.values) {
      await s.cancel();
    }
    _threadSubs.clear();
  }

  void _clearMemberState() {
    _account = const AccountState();
    _profile = null;
    _proposalRecords = <Proposal>[];
    _approved = <String>{};
    _sharedContacts = <String>{};
    _contactRequestsOut = <String>{};
    _threads = <String, MatchThread>{};
    _phones = <String, String>{};
    _contactRecords = <ContactRequestRecord>[];
    _chats = <String, List<ChatMessage>>{};
    _notifications = <NotificationItem>[];
    _docs = List<VerificationDoc>.from(VerificationDoc.blank);
    _introductions = <MatchProfile>[];
    _cursor = null;
    _exhausted = false;
    _cache.clear();
    _onboarded = false;
  }

  Future<void> _onAuth(AuthUser? user) async {
    final bool sameUser = user?.uid == _user?.uid;
    final bool wasApproved = _user?.isApproved ?? false;
    _user = user;
    if (sameUser && user != null) {
      if (user.isApproved && !wasApproved) unawaited(refreshIntroductions());
      notifyListeners();
      return;
    }
    await _closeSession();
    _clearMemberState();
    if (user == null) {
      _stage = AuthStage.guest;
      _restoring = false;
      notifyListeners();
      return;
    }
    _stage = AuthStage.onboarding;
    await _loadDraft(user.uid);
    final String uid = user.uid;
    _subs.addAll(<StreamSubscription<dynamic>>[
      _backend.watchAccount(uid).listen(_onAccount, onError: _report),
      _backend.watchLimits().listen((AppLimits l) {
        _limits = l;
        notifyListeners();
      }, onError: _report),
      _backend.watchProposals(uid).listen(_onProposals, onError: _report),
      _backend.watchMatches(uid).listen(_onMatches, onError: _report),
      _backend.watchSharedContacts(uid).listen((Map<String, String> m) {
        _phones = m;
        _sharedContacts = m.keys.toSet();
        unawaited(_ensureProfiles(m.keys));
        notifyListeners();
      }, onError: _report),
      _backend.watchContactRequests(uid).listen((List<ContactRequestRecord> r) {
        _contactRecords = r;
        _contactRequestsOut = r
            .where((ContactRequestRecord c) => !c.isIncoming)
            .map((ContactRequestRecord c) => c.profileId)
            .toSet();
        unawaited(_ensureProfiles(r.map((ContactRequestRecord c) => c.profileId)));
        notifyListeners();
      }, onError: _report),
      _backend.watchNotifications(uid).listen((List<NotificationItem> n) {
        _notifications = n;
        notifyListeners();
      }, onError: _report),
      _backend.watchDocuments(uid).listen((List<VerificationDoc> d) {
        _docs = d;
        notifyListeners();
      }, onError: _report),
    ]);
    _send(() => _backend.registerPushToken(uid));
    _restoring = false;
    notifyListeners();
  }

  Future<void> _loadDraft(String uid) async {
    try {
      final Map<String, dynamic>? draft = await _backend.loadDraft(uid);
      final AuthUser? user = _user;
      _profile = draft == null
          ? WardProfile(email: user?.email ?? '', phoneCode: '+91', country: '')
          : WardProfile.fromDraft(draft);
    } on Object catch (e) {
      _report(e);
    }
  }

  void _onAccount(AccountState account) {
    final ReviewStage before = _account.stage;
    _account = account;
    final bool approved = account.stage == ReviewStage.approved;
    _onboarded = approved;
    _stage = approved ? AuthStage.active : AuthStage.onboarding;
    // The approved claim is set just after the stage changes.
    if (approved && before != ReviewStage.approved) {
      _send(_backend.refreshClaims);
    }
    notifyListeners();
  }

  void _onProposals(List<Proposal> proposals) {
    _proposalRecords = proposals;
    unawaited(_ensureProfiles(proposals.map((Proposal p) => p.profileId)));
    notifyListeners();
  }

  void _onMatches(List<MatchThread> threads) {
    _threads = <String, MatchThread>{
      for (final MatchThread t in threads) t.otherId: t,
    };
    _approved = threads
        .where((MatchThread t) => t.isOpen)
        .map((MatchThread t) => t.otherId)
        .toSet();
    unawaited(_ensureProfiles(_approved));
    final String? uid = _user?.uid;
    if (uid != null) {
      for (final MatchThread t in threads.where((MatchThread t) => t.isOpen)) {
        _threadSubs.putIfAbsent(
          t.otherId,
          () => _backend.watchMessages(t.pairId, uid).listen(
            (List<ChatMessage> messages) {
              _chats = <String, List<ChatMessage>>{..._chats, t.otherId: messages};
              notifyListeners();
            },
            onError: _report,
          ),
        );
      }
    }
    for (final MatchThread t in threads.where((MatchThread t) => !t.isOpen)) {
      unawaited(_threadSubs.remove(t.otherId)?.cancel());
      _chats = <String, List<ChatMessage>>{..._chats}..remove(t.otherId);
    }
    notifyListeners();
  }

  // ─── Directory ────────────────────────────────────────────────────────────

  Future<void> _ensureProfiles(Iterable<String> ids) async {
    if (!(_user?.isApproved ?? false)) return;
    final List<String> missing = ids
        .where((String id) => !_cache.containsKey(id) && !_fetching.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _fetching.addAll(missing);
    try {
      for (final MatchProfile p in await _backend.getProfiles(missing)) {
        _cache[p.id] = p;
      }
      notifyListeners();
    } on Object catch (e) {
      _report(e);
    } finally {
      _fetching.removeAll(missing);
    }
  }

  @override
  List<MatchProfile> get directory => _cache.values.toList();

  @override
  MatchProfile profileById(String id) {
    final MatchProfile? known = _cache[id];
    if (known != null) return known;
    unawaited(_ensureProfiles(<String>[id]));
    return MatchProfile.unknown(id);
  }

  // ─── Sign-in ──────────────────────────────────────────────────────────────

  @override
  Future<String> sendOtp(String e164Phone) => _backend.sendOtp(e164Phone);
  @override
  Future<void> confirmOtp(String verificationId, String code) =>
      _backend.confirmOtp(verificationId, code);
  @override
  Future<void> signInWithGoogle() => _backend.signInWithGoogle();

  @override
  void signOut() => _send(_backend.signOut);

  @override
  void enterOnboarding() {}

  /// Deletes the account on the server, then local preferences.
  @override
  void resetAll() {
    _send(() async {
      await _backend.deleteAccount();
      await _prefs.clear();
    });
  }

  // ─── Draft ────────────────────────────────────────────────────────────────

  @override
  void updateProfile(WardProfile Function(WardProfile) mutate) {
    _profile = mutate(_profile ?? const WardProfile());
    notifyListeners();
    final String? uid = _user?.uid;
    final WardProfile? next = _profile;
    if (uid == null || next == null) return;
    _send(() => _backend.saveDraft(uid, _draftOf(next)));
  }

  static Map<String, dynamic> _draftOf(WardProfile p) => p.toDraft(
        qualificationGraduate: OptionLists.qualifications[p.qualification],
      );

  @override
  Future<void> saveDraft(WardProfile next) async {
    _profile = next;
    notifyListeners();
    final String? uid = _user?.uid;
    if (uid != null) await _backend.saveDraft(uid, _draftOf(next));
  }

  @override
  Future<String> uploadPhoto(String localPath) {
    final String? uid = _user?.uid;
    if (uid == null) throw const BackendException('Please sign in again.');
    return _backend.uploadPhoto(uid, localPath);
  }

  @override
  Future<String> photoSource(String stored) => _backend.photoUrl(stored);

  @override
  Future<void> removePhoto(String stored) async {
    await _backend.deletePhoto(stored);
    await super.removePhoto(stored);
  }

  @override
  Future<void> submitProfile() => _backend.submitProfile();

  // ─── Discovery ────────────────────────────────────────────────────────────

  @override
  List<MatchProfile> get discoveredProfiles => _introductions;
  @override
  bool get isLoadingIntroductions => _loadingIntros;
  @override
  String? get introductionsError => _introError;

  @override
  Future<void> refreshIntroductions() async {
    _introductions = <MatchProfile>[];
    _cursor = null;
    _exhausted = false;
    await loadMoreIntroductions();
  }

  @override
  Future<void> loadMoreIntroductions() async {
    if (_loadingIntros || _exhausted || !(_user?.isApproved ?? false)) return;
    _loadingIntros = true;
    _introError = null;
    notifyListeners();
    try {
      final IntroductionPage page =
          await _backend.fetchIntroductions(_filters, _cursor);
      final Set<String> seen = _introductions.map((MatchProfile p) => p.id).toSet();
      final List<MatchProfile> fresh =
          page.profiles.where((MatchProfile p) => seen.add(p.id)).toList();
      for (final MatchProfile p in fresh) {
        _cache[p.id] = p;
      }
      _introductions = <MatchProfile>[..._introductions, ...fresh];
      _cursor = page.cursor;
      _exhausted = page.cursor == null;
    } on Object catch (e) {
      _introError = e is BackendException
          ? e.message
          : 'Could not load introductions.';
    } finally {
      _loadingIntros = false;
      notifyListeners();
    }
  }

  void _dropIntroduction(String id) {
    _introductions = _introductions.where((MatchProfile p) => p.id != id).toList();
    if (_introductions.length < 3) unawaited(loadMoreIntroductions());
  }

  @override
  void setFilters(MatchFilters next) {
    super.setFilters(next);
    unawaited(refreshIntroductions());
  }

  @override
  void markIncompatible(String matchId) {
    _dropIntroduction(matchId);
    notifyListeners();
    _send(() => _backend.hideProfile(matchId));
  }

  // ─── Proposals and contact ────────────────────────────────────────────────

  @override
  bool sendProposal(String matchId) {
    if (hasProposed(matchId)) return true;
    if (proposalsLeft == 0) return false;
    _dropIntroduction(matchId);
    notifyListeners();
    _send(() => _backend.sendProposal(matchId));
    return true;
  }

  @override
  bool acceptProposal(String matchId) {
    if (!(incomingProposal(matchId)?.isPending ?? false)) return false;
    _send(() => _backend.respondProposal(matchId, accept: true));
    return true;
  }

  @override
  bool declineProposal(String matchId) {
    if (!(incomingProposal(matchId)?.isPending ?? false)) return false;
    _send(() => _backend.respondProposal(matchId, accept: false));
    return true;
  }

  @override
  bool withdrawProposal(String matchId) {
    if (!(outgoingProposal(matchId)?.isPending ?? false)) return false;
    _send(() => _backend.withdrawProposal(matchId));
    return true;
  }

  @override
  bool requestContact(String matchId) {
    if (isContactShared(matchId) || contactRequested(matchId)) return true;
    if (contactCredits <= 0) return false;
    _dropIntroduction(matchId);
    notifyListeners();
    _send(() => _backend.requestContact(matchId));
    return true;
  }

  @override
  List<MatchProfile> get incomingContactRequests => _contactRecords
      .where((ContactRequestRecord c) => c.isIncoming && c.status == 'pending')
      .map((ContactRequestRecord c) => profileById(c.profileId))
      .toList();

  @override
  Future<void> respondContact(String matchId, {required bool accept}) =>
      _backend.respondContact(matchId, accept: accept);

  @override
  String sharedPhone(String matchId) => _phones[matchId] ?? '';

  // ─── Matches and chat ─────────────────────────────────────────────────────

  @override
  void unmatch(String matchId) => _send(() => _backend.unmatch(matchId));

  @override
  void blockProfile(String matchId) {
    _blocked = <String>{..._blocked, matchId};
    _dropIntroduction(matchId);
    notifyListeners();
    _send(() => _backend.blockProfile(matchId));
  }

  @override
  void reportProfile(String matchId, String reason) =>
      _send(() => _backend.reportProfile(matchId, reason));

  @override
  void sendMessage(String matchId, String text) {
    final String trimmed = text.trim();
    final MatchThread? thread = _threads[matchId];
    final String? uid = _user?.uid;
    if (trimmed.isEmpty || thread == null || !thread.isOpen || uid == null) return;
    _send(() => _backend.sendMessage(thread.pairId, uid, trimmed));
  }

  @override
  void markThreadRead(String matchId) {
    super.markThreadRead(matchId);
    final MatchThread? thread = _threads[matchId];
    final String? uid = _user?.uid;
    if (thread != null && uid != null) {
      _send(() => _backend.markThreadRead(thread.pairId, uid));
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  @override
  void markNotificationRead(String id) {
    final String? uid = _user?.uid;
    if (uid != null) _send(() => _backend.markNotificationRead(uid, id));
  }

  @override
  void markAllNotificationsRead() {
    final String? uid = _user?.uid;
    if (uid == null) return;
    for (final NotificationItem n in _notifications.where((NotificationItem n) => !n.isRead)) {
      _send(() => _backend.markNotificationRead(uid, n.id));
    }
  }

  // ─── Verification and purchases ───────────────────────────────────────────

  @override
  Future<void> uploadVerificationDoc(String docId, List<String> localPaths) {
    final String? uid = _user?.uid;
    if (uid == null) throw const BackendException('Please sign in again.');
    return _backend.submitDocument(uid, docId, localPaths);
  }

  @override
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
    String? packageName,
  }) =>
      _backend.validatePurchase(
        productId: productId,
        platform: platform,
        token: token,
        packageName: packageName,
      );

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    unawaited(_closeSession());
    super.dispose();
  }
}

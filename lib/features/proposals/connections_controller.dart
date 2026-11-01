import 'dart:async';

import '../../data/backend.dart';
import '../../models/match_profile.dart';
import '../../models/proposal.dart';
import '../core/feature_controller.dart';
import '../discovery/discovery_controller.dart';
import '../messaging/chat_controller.dart';
import '../session/session_controller.dart';

/// Proposals and contact requests, both mirrored from the server.
class ConnectionsController extends FeatureController {
  ConnectionsController(super.backend, super.report, this._session, this._discovery, this._chat);

  final SessionController _session;
  final DiscoveryController _discovery;
  final ChatController _chat;

  List<Proposal> _proposals = <Proposal>[];
  List<ContactRequestRecord> _contacts = <ContactRequestRecord>[];
  Map<String, String> _phones = <String, String>{};

  void start(String uid) {
    follow(backend.watchProposals(uid), (List<Proposal> p) {
      _proposals = p;
      unawaited(_discovery.ensure(p.map((Proposal x) => x.profileId)));
      notifyListeners();
    });
    follow(backend.watchSharedContacts(uid), (Map<String, String> m) {
      _phones = m;
      unawaited(_discovery.ensure(m.keys));
      notifyListeners();
    });
    follow(backend.watchContactRequests(uid), (List<ContactRequestRecord> r) {
      _contacts = r;
      unawaited(_discovery.ensure(r.map((ContactRequestRecord c) => c.profileId)));
      notifyListeners();
    });
  }

  // ─── Quotas ──────────────────────────────────────────────────────────────

  int get proposalsLeft {
    if (_session.isPremium) return 1 << 30;
    final int left = _session.limits.proposalsPerDay - _session.account.proposalsSentToday;
    return left < 0 ? 0 : left;
  }

  int get contactCredits {
    final int left = _session.limits.monthlyContactCredits + _session.account.contactCreditsLeft;
    return left < 0 ? 0 : left;
  }

  /// Removes the card while the server decides, and restores it on refusal,
  /// so the deck never claims something that did not happen.
  Future<void> _withCard(String id, Future<void> Function() call) async {
    final MatchProfile? card = _discovery.cached(id);
    _discovery.drop(id);
    notifyListeners();
    try {
      await call();
    } on Object catch (e) {
      if (card != null) _discovery.restore(card);
      report(e);
    }
  }

  // ─── Proposals ───────────────────────────────────────────────────────────

  Proposal? proposalFor(String id, ProposalDirection direction) {
    for (final Proposal p in _proposals) {
      if (p.profileId == id && p.direction == direction) return p;
    }
    return null;
  }

  Proposal? outgoing(String id) => proposalFor(id, ProposalDirection.outgoing);
  Proposal? incoming(String id) => proposalFor(id, ProposalDirection.incoming);

  /// A withdrawn or declined proposal is not live, so the heart comes back.
  bool hasProposed(String id) {
    final Proposal? p = outgoing(id);
    return p != null &&
        (p.status == ProposalStatus.pending || p.status == ProposalStatus.accepted);
  }

  List<Proposal> get sent => _proposals
      .where((Proposal p) => p.isOutgoing && p.status != ProposalStatus.withdrawn)
      .where((Proposal p) => !_discovery.isBlocked(p.profileId))
      .toList()
    ..sort((Proposal a, Proposal b) => b.createdAt.compareTo(a.createdAt));

  List<Proposal> get pendingIncoming => _proposals
      .where((Proposal p) => p.isIncoming && p.isPending)
      .toList()
    ..sort((Proposal a, Proposal b) => b.createdAt.compareTo(a.createdAt));

  bool sendProposal(String id) {
    if (hasProposed(id)) return true;
    if (proposalsLeft == 0) return false;
    unawaited(_withCard(id, () => backend.sendProposal(id)));
    return true;
  }

  bool accept(String id) {
    if (!(incoming(id)?.isPending ?? false)) return false;
    send(() => backend.respondProposal(id, accept: true));
    return true;
  }

  bool decline(String id) {
    if (!(incoming(id)?.isPending ?? false)) return false;
    send(() => backend.respondProposal(id, accept: false));
    return true;
  }

  bool withdraw(String id) {
    if (!(outgoing(id)?.isPending ?? false)) return false;
    send(() => backend.withdrawProposal(id));
    return true;
  }

  // ─── Contact ─────────────────────────────────────────────────────────────

  bool isContactShared(String id) => _phones.containsKey(id);
  String sharedPhone(String id) => _phones[id] ?? '';

  bool contactRequested(String id) =>
      _contacts.any((ContactRequestRecord c) => !c.isIncoming && c.profileId == id);

  bool requestContact(String id) {
    if (isContactShared(id) || contactRequested(id)) return true;
    if (contactCredits <= 0) return false;
    unawaited(_withCard(id, () => backend.requestContact(id)));
    return true;
  }

  List<MatchProfile> get incomingContactRequests => _contacts
      .where((ContactRequestRecord c) => c.isIncoming && c.status == 'pending')
      .map((ContactRequestRecord c) => _discovery.profileById(c.profileId))
      .toList();

  Future<void> respondContact(String id, {required bool accept}) =>
      backend.respondContact(id, accept: accept);

  /// Contact requests waiting on either side.
  List<MatchProfile> get pendingContacts => _contacts
      .where((ContactRequestRecord c) => c.status == 'pending')
      .map((ContactRequestRecord c) => _discovery.profileById(c.profileId))
      .toList();

  // ─── Decks ───────────────────────────────────────────────────────────────

  /// Matches who have not exchanged contact details.
  List<MatchProfile> get chatMatches => _discovery.directory
      .where((MatchProfile p) => _chat.isMatched(p.id))
      .where((MatchProfile p) => !isContactShared(p.id))
      .where((MatchProfile p) => !_discovery.isBlocked(p.id))
      .toList();

  List<MatchProfile> get sharedContactProfiles => _discovery.directory
      .where((MatchProfile p) => isContactShared(p.id))
      .where((MatchProfile p) => !_discovery.isBlocked(p.id))
      .toList();

  @override
  Future<void> stop() async {
    await super.stop();
    _proposals = <Proposal>[];
    _contacts = <ContactRequestRecord>[];
    _phones = <String, String>{};
  }
}

import 'dart:convert';

/// Which side opened the proposal.
enum ProposalDirection {
  /// This member sent it to someone else.
  outgoing,

  /// Someone else sent it to this member.
  incoming,
}

/// Lifecycle of a single proposal.
///
/// Replaces the parallel `Set<String>` flags that previously stood in for this
/// lifecycle and allowed contradictory combinations (see
/// `docs/GAP_ANALYSIS.md` G-04).
enum ProposalStatus {
  /// Sent, awaiting the other side's decision.
  pending,

  /// The recipient accepted. Only this status may produce a match.
  accepted,

  /// The recipient declined.
  declined,

  /// The sender took it back before a decision.
  withdrawn,

  /// Timed out without a decision.
  expired,
}

extension ProposalStatusX on ProposalStatus {
  bool get isTerminal => this != ProposalStatus.pending;

  String get label => switch (this) {
    ProposalStatus.pending => 'Pending',
    ProposalStatus.accepted => 'Accepted',
    ProposalStatus.declined => 'Declined',
    ProposalStatus.withdrawn => 'Withdrawn',
    ProposalStatus.expired => 'Expired',
  };

  /// Status line shown on a proposal this member sent.
  String get outgoingDetail => switch (this) {
    ProposalStatus.pending => 'Awaiting a reply',
    ProposalStatus.accepted => 'Accepted — you are matched',
    ProposalStatus.declined => 'Not taken forward',
    ProposalStatus.withdrawn => 'You withdrew this proposal',
    ProposalStatus.expired => 'Expired without a reply',
  };

  /// Status line shown on a proposal this member received.
  String get incomingDetail => switch (this) {
    ProposalStatus.pending => 'Sent you a proposal',
    ProposalStatus.accepted => 'You accepted — you are matched',
    ProposalStatus.declined => 'You declined this proposal',
    ProposalStatus.withdrawn => 'Withdrawn by the sender',
    ProposalStatus.expired => 'Expired without a reply',
  };
}

/// A proposal between this member and one other profile.
///
/// Exactly one proposal is tracked per profile per direction; `id` is stable so
/// a record can be reconciled with a backend row later.
class Proposal {
  final String id;
  final String profileId;
  final ProposalDirection direction;
  final ProposalStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const Proposal({
    required this.id,
    required this.profileId,
    required this.direction,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isOutgoing => direction == ProposalDirection.outgoing;
  bool get isIncoming => direction == ProposalDirection.incoming;
  bool get isPending => status == ProposalStatus.pending;
  bool get isAccepted => status == ProposalStatus.accepted;

  /// Status line appropriate to this proposal's direction.
  String get detail =>
      isOutgoing ? status.outgoingDetail : status.incomingDetail;

  // ─── Transition rules ──────────────────────────────────────────────────────

  /// The only status changes this model permits.
  ///
  /// A terminal status is final: nothing may reopen a proposal, so a declined
  /// proposal can never silently become accepted. Re-engaging requires a new
  /// proposal record.
  static const Map<ProposalStatus, Set<ProposalStatus>> allowedTransitions =
      <ProposalStatus, Set<ProposalStatus>>{
    ProposalStatus.pending: <ProposalStatus>{
      ProposalStatus.accepted,
      ProposalStatus.declined,
      ProposalStatus.withdrawn,
      ProposalStatus.expired,
    },
    ProposalStatus.accepted: <ProposalStatus>{},
    ProposalStatus.declined: <ProposalStatus>{},
    ProposalStatus.withdrawn: <ProposalStatus>{},
    ProposalStatus.expired: <ProposalStatus>{},
  };

  /// Whether [from] may become [to].
  static bool canTransition(ProposalStatus from, ProposalStatus to) =>
      allowedTransitions[from]?.contains(to) ?? false;

  /// Which side is allowed to move a proposal into [to].
  ///
  /// Accept and decline belong to the recipient; withdraw belongs to the
  /// sender. Expiry is driven by the clock, so either side may observe it.
  static bool isActorAllowed(ProposalDirection direction, ProposalStatus to) =>
      switch (to) {
        ProposalStatus.accepted ||
        ProposalStatus.declined =>
          direction == ProposalDirection.incoming,
        ProposalStatus.withdrawn => direction == ProposalDirection.outgoing,
        ProposalStatus.expired => true,
        ProposalStatus.pending => false,
      };

  /// Returns this proposal moved to [next], or `null` when the move is not
  /// allowed by [canTransition] / [isActorAllowed].
  ///
  /// Returning `null` rather than throwing keeps illegal input a decision the
  /// caller handles, not a crash.
  Proposal? tryTransition(ProposalStatus next, {DateTime? at}) {
    if (!canTransition(status, next)) return null;
    if (!isActorAllowed(direction, next)) return null;
    return copyWith(status: next, respondedAt: at ?? DateTime.now());
  }

  Proposal copyWith({
    ProposalStatus? status,
    DateTime? respondedAt,
  }) =>
      Proposal(
        id: id,
        profileId: profileId,
        direction: direction,
        status: status ?? this.status,
        createdAt: createdAt,
        respondedAt: respondedAt ?? this.respondedAt,
      );

  // ─── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'profileId': profileId,
        'direction': direction.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        direction: ProposalDirection.values.asNameMap()[json['direction']] ??
            ProposalDirection.outgoing,
        status: ProposalStatus.values.asNameMap()[json['status']] ??
            ProposalStatus.pending,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        respondedAt: DateTime.tryParse(json['respondedAt'] as String? ?? ''),
      );

  static String encodeList(List<Proposal> list) =>
      jsonEncode(list.map((Proposal p) => p.toJson()).toList());

  static List<Proposal> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <Proposal>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <Proposal>[];
      return decoded
          .cast<Map<String, dynamic>>()
          .map(Proposal.fromJson)
          .toList();
    } catch (_) {
      return <Proposal>[];
    }
  }

  @override
  String toString() =>
      'Proposal($profileId, ${direction.name}, ${status.name})';
}

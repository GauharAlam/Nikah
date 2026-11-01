import 'package:flutter_test/flutter_test.dart';

import 'package:nikah_app/models/proposal.dart';

Proposal _proposal({
  ProposalDirection direction = ProposalDirection.incoming,
  ProposalStatus status = ProposalStatus.pending,
}) =>
    Proposal(
      id: 'p1',
      profileId: 'farhan-2',
      direction: direction,
      status: status,
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  group('transition table', () {
    test('pending may move to any terminal status', () {
      for (final ProposalStatus to in <ProposalStatus>[
        ProposalStatus.accepted,
        ProposalStatus.declined,
        ProposalStatus.withdrawn,
        ProposalStatus.expired,
      ]) {
        expect(
          Proposal.canTransition(ProposalStatus.pending, to),
          isTrue,
          reason: 'pending -> ${to.name} should be allowed',
        );
      }
    });

    test('pending may not transition to itself', () {
      expect(
        Proposal.canTransition(ProposalStatus.pending, ProposalStatus.pending),
        isFalse,
      );
    });

    test('every terminal status is final', () {
      final List<ProposalStatus> terminals = <ProposalStatus>[
        ProposalStatus.accepted,
        ProposalStatus.declined,
        ProposalStatus.withdrawn,
        ProposalStatus.expired,
      ];
      for (final ProposalStatus from in terminals) {
        for (final ProposalStatus to in ProposalStatus.values) {
          expect(
            Proposal.canTransition(from, to),
            isFalse,
            reason: '${from.name} is terminal but allowed -> ${to.name}',
          );
        }
      }
    });

    test('a declined proposal can never become accepted', () {
      final Proposal declined =
          _proposal(status: ProposalStatus.declined);
      expect(declined.tryTransition(ProposalStatus.accepted), isNull);
    });

    test('the full matrix matches the documented table', () {
      // Exhaustive: 5 statuses x 5 statuses. Only pending -> terminal passes.
      for (final ProposalStatus from in ProposalStatus.values) {
        for (final ProposalStatus to in ProposalStatus.values) {
          final bool expected = from == ProposalStatus.pending &&
              to != ProposalStatus.pending;
          expect(
            Proposal.canTransition(from, to),
            expected,
            reason: '${from.name} -> ${to.name}',
          );
        }
      }
    });
  });

  group('actor rules', () {
    test('only the recipient may accept or decline', () {
      expect(
        Proposal.isActorAllowed(
            ProposalDirection.incoming, ProposalStatus.accepted),
        isTrue,
      );
      expect(
        Proposal.isActorAllowed(
            ProposalDirection.outgoing, ProposalStatus.accepted),
        isFalse,
      );
      expect(
        Proposal.isActorAllowed(
            ProposalDirection.outgoing, ProposalStatus.declined),
        isFalse,
      );
    });

    test('only the sender may withdraw', () {
      expect(
        Proposal.isActorAllowed(
            ProposalDirection.outgoing, ProposalStatus.withdrawn),
        isTrue,
      );
      expect(
        Proposal.isActorAllowed(
            ProposalDirection.incoming, ProposalStatus.withdrawn),
        isFalse,
      );
    });

    test('a sender cannot accept their own proposal', () {
      final Proposal outgoing =
          _proposal(direction: ProposalDirection.outgoing);
      expect(
        outgoing.tryTransition(ProposalStatus.accepted),
        isNull,
        reason: 'accepting your own proposal would fake mutual consent',
      );
    });

    test('a recipient cannot withdraw a proposal sent to them', () {
      expect(_proposal().tryTransition(ProposalStatus.withdrawn), isNull);
    });
  });

  group('tryTransition', () {
    test('a permitted move stamps respondedAt', () {
      final Proposal? accepted =
          _proposal().tryTransition(ProposalStatus.accepted);
      expect(accepted, isNotNull);
      expect(accepted!.status, ProposalStatus.accepted);
      expect(accepted.respondedAt, isNotNull);
      expect(accepted.createdAt, DateTime(2026, 10, 1));
      expect(accepted.id, 'p1');
    });

    test('a refused move returns null and mutates nothing', () {
      final Proposal accepted = _proposal(status: ProposalStatus.accepted);
      expect(accepted.tryTransition(ProposalStatus.declined), isNull);
      expect(accepted.status, ProposalStatus.accepted);
    });
  });

  group('serialization', () {
    test('round-trips through json', () {
      final Proposal original = Proposal(
        id: 'p9',
        profileId: 'salman-5',
        direction: ProposalDirection.incoming,
        status: ProposalStatus.declined,
        createdAt: DateTime(2026, 5, 4, 13, 30),
        respondedAt: DateTime(2026, 5, 5, 9, 15),
      );

      final Proposal decoded =
          Proposal.decodeList(Proposal.encodeList(<Proposal>[original])).single;

      expect(decoded.id, original.id);
      expect(decoded.profileId, original.profileId);
      expect(decoded.direction, original.direction);
      expect(decoded.status, original.status);
      expect(decoded.createdAt, original.createdAt);
      expect(decoded.respondedAt, original.respondedAt);
    });

    test('malformed input decodes to an empty list rather than throwing', () {
      expect(Proposal.decodeList('not json'), isEmpty);
      expect(Proposal.decodeList(''), isEmpty);
      expect(Proposal.decodeList(null), isEmpty);
    });

    test('an unknown status falls back to pending', () {
      final Proposal p = Proposal.fromJson(<String, dynamic>{
        'id': 'p1',
        'profileId': 'x',
        'direction': 'sideways',
        'status': 'teleported',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(p.status, ProposalStatus.pending);
      expect(p.direction, ProposalDirection.outgoing);
    });
  });
}

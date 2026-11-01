// Proposals tab — hearts you sent (with daily quota) and contact requests
// received from other families.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../l10n/app_strings.dart';
import '../models/match_profile.dart';
import '../models/proposal.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

enum _ProposalTab { sent, received }

/// Proposals tab of the home shell.
class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  _ProposalTab _tab = _ProposalTab.sent;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<Proposal> sent = store.sentProposals;
    final List<Proposal> received = store.pendingIncomingProposals;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          tr('Proposals'),
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _QuotaBanner(
            used: store.proposalsSentToday,
            quota: store.dailyProposalLimit,
            credits: store.contactCredits,
          ),
          const SizedBox(height: 14),
          AppSegmentedToggle<_ProposalTab>(
            options: <SegmentedOption<_ProposalTab>>[
              SegmentedOption<_ProposalTab>(
                value: _ProposalTab.sent,
                label: trArgs('Sent ({count})', <String, Object>{'count': sent.length}),
                icon: Icons.favorite_rounded,
              ),
              SegmentedOption<_ProposalTab>(
                value: _ProposalTab.received,
                label: trArgs('Received ({count})', <String, Object>{'count': received.length}),
                icon: Icons.mark_email_unread_outlined,
              ),
            ],
            selected: _tab,
            onChanged: (_ProposalTab next) => setState(() => _tab = next),
          ),
          const SizedBox(height: 14),
          if (_tab == _ProposalTab.sent)
            if (sent.isEmpty)
              EmptyState(
                icon: Icons.favorite_outline_rounded,
                title: tr('No proposals yet'),
                body: tr('Tap the green heart on a profile to send your first '
                    'proposal.'),
              )
            else
              for (final Proposal p in sent) ...<Widget>[
                _SentProposalCard(
                  profile: store.profileById(p.profileId),
                  proposal: p,
                ),
                const SizedBox(height: 10),
              ],
          if (_tab == _ProposalTab.received)
            if (received.isEmpty && store.incomingContactRequests.isEmpty)
              EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: tr('No proposals received'),
                body: tr('When someone sends you a proposal it will appear here '
                    'for you to accept or decline.'),
              )
            else
              for (final Proposal p in received) ...<Widget>[
                _ReceivedProposalCard(
                  profile: store.profileById(p.profileId),
                  proposal: p,
                ),
                const SizedBox(height: 10),
              ],
          if (_tab == _ProposalTab.received)
            for (final MatchProfile p in store.incomingContactRequests)
              ListTile(
                key: Key('contact_request_${p.id}'),
                title: Text(p.name),
                subtitle: Text(tr('Requested your contact details')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: tr('Decline'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => store.respondContact(p.id, accept: false),
                    ),
                    IconButton(
                      tooltip: tr('Share my contact'),
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () => store.respondContact(p.id, accept: true),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Header summary of the daily proposal quota and gold credits.
class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({
    required this.used,
    required this.quota,
    required this.credits,
  });

  final int used;
  final int quota;
  final int credits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.brandWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr('TODAY\'S PROPOSALS'),
                  style: AppTheme.ts(
                    9.5,
                    FontWeight.w800,
                    color: AppTheme.mint,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trArgs('{used} of {quota} sent', <String, Object>{'used': used, 'quota': quota}),
                  style: AppTheme.ts(18, FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quota == 0 ? 0 : (used / quota).clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mint),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: <Widget>[
                const Icon(Icons.phone_rounded, size: 16, color: AppTheme.gold),
                const SizedBox(height: 4),
                Text(
                  '$credits',
                  style: AppTheme.ts(16, FontWeight.w800, color: Colors.white),
                ),
                Text(
                  tr('CREDITS'),
                  style: AppTheme.ts(
                    7.5,
                    FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round avatar with initials fallback used across proposal cards.
class _ProposalAvatar extends StatelessWidget {
  const _ProposalAvatar({required this.profile});

  final MatchProfile profile;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 52,
        height: 52,
        child: AppNetworkImage(url: profile.imageUrl),
      ),
    );
  }
}

class _SentProposalCard extends StatelessWidget {
  const _SentProposalCard({required this.profile, required this.proposal});

  final MatchProfile profile;
  final Proposal proposal;

  /// Colour and icon follow the proposal's own status, not contact sharing.
  Future<void> _withdraw(BuildContext context) async {
    final AppStore store = context.read<AppStore>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(tr('Withdraw this proposal?')),
        content: Text(tr('They will no longer be able to answer it.')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            key: const Key('confirm_withdraw'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Withdraw')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final bool done = await store.withdrawProposal(profile.id);
      if (context.mounted && done) showSuccessSnack(context, 'Proposal withdrawn.');
    } on Object {
      if (context.mounted) showAppSnack(context, 'Could not withdraw. Please try again.');
    }
  }

  (IconData, Color) get _statusStyle => switch (proposal.status) {
        ProposalStatus.accepted => (
            Icons.check_circle_rounded,
            AppTheme.success,
          ),
        ProposalStatus.declined || ProposalStatus.expired => (
            Icons.do_not_disturb_on_outlined,
            AppTheme.slate500,
          ),
        _ => (Icons.hourglass_bottom_rounded, AppTheme.goldDeep),
      };

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _statusStyle;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          _ProposalAvatar(profile: profile),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${profile.name}, ${profile.age}',
                  style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.profession,
                  style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tr(proposal.detail),
                        style: AppTheme.ts(11.5, FontWeight.w700, color: color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (proposal.isPending)
            TextButton(
              key: Key('withdraw_proposal_${profile.id}'),
              onPressed: () => _withdraw(context),
              child: Text(tr('Withdraw')),
            ),
          IconButton(
            onPressed: () => context.push(AppRoutes.matchDetail(profile.id)),
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: AppTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedProposalCard extends StatelessWidget {
  const _ReceivedProposalCard({
    required this.profile,
    required this.proposal,
  });

  final MatchProfile profile;
  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _ProposalAvatar(profile: profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: AppTheme.ts(
                        14.5,
                        FontWeight.w800,
                        color: AppTheme.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.profession} · ${profile.location}',
                      style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      proposal.detail,
                      style: AppTheme.ts(11.5, FontWeight.w700, color: AppTheme.green),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: Key('decline_proposal_${profile.id}'),
                  onPressed: () {
                    if (context.read<AppStore>().declineProposal(profile.id)) {
                      showAppSnack(context, 'Proposal declined politely.',
                          icon: Icons.do_not_disturb_on_outlined);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.slate700,
                    side: BorderSide(color: AppTheme.slate200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(tr('Decline')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  key: Key('accept_proposal_${profile.id}'),
                  label: tr('Accept'),
                  onPressed: () {
                    if (context.read<AppStore>().acceptProposal(profile.id)) {
                      showSuccessSnack(
                        context,
                        trArgs('Matched with {name} — interest is mutual.', <String, Object>{'name': profile.firstName}),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Proposals tab — hearts you sent (with daily quota) and contact requests
// received from other families (Barkat style).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/match_profile.dart';
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
    final List<MatchProfile> sent = store.proposalsSentList;
    final List<MatchProfile> received = store.incomingContactRequests;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Proposals',
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _QuotaBanner(
            used: store.proposalsSentToday,
            quota: AppStore.proposalQuota,
            credits: store.contactCredits,
          ),
          const SizedBox(height: 14),
          AppSegmentedToggle<_ProposalTab>(
            options: <SegmentedOption<_ProposalTab>>[
              SegmentedOption<_ProposalTab>(
                value: _ProposalTab.sent,
                label: 'Sent (${sent.length})',
                icon: Icons.favorite_rounded,
              ),
              SegmentedOption<_ProposalTab>(
                value: _ProposalTab.received,
                label: 'Received (${received.length})',
                icon: Icons.mark_email_unread_outlined,
              ),
            ],
            selected: _tab,
            onChanged: (_ProposalTab next) => setState(() => _tab = next),
          ),
          const SizedBox(height: 14),
          if (_tab == _ProposalTab.sent)
            if (sent.isEmpty)
              const EmptyState(
                icon: Icons.favorite_outline_rounded,
                title: 'No proposals yet',
                body: 'Tap the green heart on a profile to send your first '
                    'proposal. You get five every day.',
              )
            else
              for (final MatchProfile p in sent) ...<Widget>[
                _SentProposalCard(profile: p),
                const SizedBox(height: 10),
              ],
          if (_tab == _ProposalTab.received)
            if (received.isEmpty)
              const EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: 'No requests received',
                body: 'When a family requests your contact details it will '
                    'appear here for your approval.',
              )
            else
              for (final MatchProfile p in received) ...<Widget>[
                _ReceivedRequestCard(profile: p),
                const SizedBox(height: 10),
              ],
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
                  'TODAY\'S PROPOSALS',
                  style: AppTheme.ts(
                    9.5,
                    FontWeight.w800,
                    color: AppTheme.mint,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$used of $quota sent',
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
                  'CREDITS',
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
  const _SentProposalCard({required this.profile});

  final MatchProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.read<AppStore>();
    final bool shared = store.isContactShared(profile.id);
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
                    Icon(
                      shared
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 13,
                      color: shared ? AppTheme.success : AppTheme.goldDeep,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        shared ? 'Contact shared' : 'Awaiting a reply',
                        style: AppTheme.ts(
                          11.5,
                          FontWeight.w700,
                          color: shared ? AppTheme.success : AppTheme.goldDeep,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

class _ReceivedRequestCard extends StatelessWidget {
  const _ReceivedRequestCard({required this.profile});

  final MatchProfile profile;

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
                      'Requested your contact details',
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
                  onPressed: () {
                    context.read<AppStore>().declineContact(profile.id);
                    showAppSnack(context, 'Request declined politely.',
                        icon: Icons.do_not_disturb_on_outlined);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.slate700,
                    side: BorderSide(color: AppTheme.slate200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  onPressed: () {
                    context.read<AppStore>().acceptContact(profile.id);
                    showSuccessSnack(
                        context, 'Contact shared with ${profile.firstName}.');
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

// Match detail — Barkat-style profile sheet: photo carousel with quote
// overlay, "TAKE THE NEXT STEP" stacked context actions, then the biodata.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_snacks.dart';

/// Local shorthand for theme text styles inside this screen.
TextStyle _t(double size, FontWeight weight, Color color) =>
    AppTheme.ts(size, weight, color: color);

/// Full biodata screen for one suitor, opened from deck, hub or proposals.
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final PageController _photoController = PageController();
  int _photoIndex = 0;
  bool _saved = false;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  void _openPhoto(MatchProfile match) {
    context.push(
      '${AppRoutes.photo(match.id)}'
      '?url=${Uri.encodeComponent(match.imageUrl)}'
      '&name=${Uri.encodeComponent(match.firstName)}',
    );
  }

  void _sendProposal(MatchProfile match) {
    final bool ok = context.read<AppStore>().sendProposal(match.id);
    if (ok) {
      showWaliSnack(context, 'Proposal sent to ${match.waliName}');
    } else {
      showAppSnack(
        context,
        'Daily limit reached — 5 proposals per day. Come back tomorrow.',
        icon: Icons.hourglass_top_rounded,
      );
    }
  }

  void _requestContact(MatchProfile match) {
    final bool ok = context.read<AppStore>().requestContact(match.id);
    if (ok) {
      showWaliSnack(
        context,
        'Contact request sent · 1 gold credit used',
      );
    } else {
      showAppSnack(
        context,
        'No gold credits left — top up from the Premium tab.',
        icon: Icons.diamond_outlined,
      );
    }
  }

  void _markIncompatible(MatchProfile match) {
    context.read<AppStore>().markIncompatible(match.id);
    showAppSnack(
      context,
      '${match.firstName} hidden from your deck.',
      icon: Icons.do_not_disturb_on_outlined,
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.homeDiscovery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final MatchProfile match = MatchProfile.byId(widget.matchId);
    final bool shared = store.isContactShared(match.id);
    final bool approved = store.isApproved(match.id);
    final bool requested = store.contactRequested(match.id);
    final bool proposed = store.hasProposed(match.id);
    final bool incoming = store.incomingProposal(match.id)?.isPending ?? false;
    final int activeDays = match.id.hashCode.abs() % 4 + 2;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          key: const Key('detail_back'),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.homeDiscovery);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Profile details',
          style: _t(16.5, FontWeight.w800, AppTheme.slate900),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share profile',
            onPressed: () => showAppSnack(
              context,
              'Sharing unlocks after both families approve the match.',
              icon: Icons.ios_share_rounded,
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 21),
          ),
          IconButton(
            tooltip: 'More options',
            onPressed: () => showAppSnack(
              context,
              'Report or block options are reviewed by the trust team.',
              icon: Icons.more_vert_rounded,
            ),
            icon: const Icon(Icons.more_vert_rounded, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildCarousel(match),
          _buildHeader(match, activeDays),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Text(
                    'TAKE THE NEXT STEP',
                    style: _t(
                      10.5,
                      FontWeight.w800,
                      AppTheme.slate500,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildSteps(
                  match,
                  store: store,
                  shared: shared,
                  approved: approved,
                  requested: requested,
                  proposed: proposed,
                  incoming: incoming,
                ),
                const SizedBox(height: 26),
                if (shared) ...<Widget>[
                  _ContactCard(match: match),
                  const SizedBox(height: 18),
                ],
                const SectionHeader(
                  'Biodata Snapshot',
                  subtitle: 'Key demographics reviewed by the Wali',
                ),
                const SizedBox(height: 12),
                _demGrid(<(String, String)>[
                  ('Age', '${match.age} years'),
                  ('Height', match.height),
                  ('Education', match.education),
                  ('University', match.university),
                  ('Marital Status', match.maritalStatus),
                  ('Location', match.location),
                  ('Profession', match.employer),
                  ('Sect', match.sect),
                ]),
                const SizedBox(height: 22),
                const SectionLabel('Faith Practice'),
                const SizedBox(height: 10),
                _PracticeCard(practices: match.religiousPractices),
                const SizedBox(height: 22),
                const SectionHeader('About Me'),
                const SizedBox(height: 8),
                Text(match.aboutMe, style: AppTheme.bodyLarge),
                const SizedBox(height: 22),
                const SectionHeader('Languages & Interests'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String language in match.languages.split(','))
                      TagChip(language.trim()),
                    for (final String hobby in match.hobbies)
                      TagChip(
                        hobby,
                        icon: Icons.interests_outlined,
                        selected: true,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _GuardianCard(match: match),
                const SizedBox(height: 14),
                InfoBanner(
                  icon: shared
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.privacy_tip_outlined,
                  variant: InfoVariant.info,
                  text: shared
                      ? 'Contact details are visible to both families. '
                            'Please involve your Wali in the first call '
                            'and keep messages respectful.'
                      : 'Photo privacy — profiles stay modest until '
                            'contact approval, and all introductions '
                            'route through the Wali.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Photo carousel (1/2 counter · quote overlay · dots) ─────────────────
  Widget _buildCarousel(MatchProfile match) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 0.84,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: PageView(
                  controller: _photoController,
                  onPageChanged: (int i) => setState(() => _photoIndex = i),
                  children: <Widget>[
                    _PhotoSlide(
                      match: match,
                      slideKey: Key('photo_${match.id}'),
                      showQuote: true,
                      onOpen: () => _openPhoto(match),
                    ),
                    _PhotoSlide(
                      match: match,
                      showQuote: false,
                      onOpen: () => _openPhoto(match),
                    ),
                  ],
                ),
              ),
              const Positioned(top: 12, left: 12, child: _MiniCrest()),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101613).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_photoIndex + 1}/2',
                    style: _t(10.5, FontWeight.w800, Colors.white),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101613).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _CarouselDot(active: _photoIndex == 0),
                      const SizedBox(width: 5),
                      _CarouselDot(active: _photoIndex == 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(MatchProfile match, int activeDays) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${match.name}, ${match.age} Yrs',
                  style: _t(23, FontWeight.w800, AppTheme.slate900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: AppTheme.slate200),
                ),
                child: InkWell(
                  key: const Key('detail_save'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    setState(() => _saved = !_saved);
                    showAppSnack(
                      context,
                      _saved
                          ? 'Saved to your shortlist.'
                          : 'Removed from your shortlist.',
                      icon: _saved
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_remove_rounded,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 19,
                      color: _saved ? AppTheme.green : AppTheme.slate600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Active ${activeDays}d ago',
                style: _t(12, FontWeight.w600, AppTheme.slate500),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppTheme.slate500,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  match.location,
                  style: _t(13, FontWeight.w600, AppTheme.slate700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (match.isNew || match.isSelfManaged) ...<Widget>[
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                if (match.isNew) ...<Widget>[
                  const _CoverPill('New profile', highlight: true),
                  const SizedBox(width: 6),
                ],
                if (match.isSelfManaged)
                  const _CoverPill('Self-managed'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.slate200.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  // ─── Contextual step buttons ──────────────────────────────────────────────
  List<Widget> _buildSteps(
    MatchProfile match, {
    required AppStore store,
    required bool shared,
    required bool approved,
    required bool requested,
    required bool proposed,
    required bool incoming,
  }) {
    if (incoming) {
      return <Widget>[
        _StepButton(
          key: const Key('detail_accept'),
          title: 'Accept Proposal',
          subtitle: 'They sent you a proposal — accepting makes it a match',
          icon: Icons.check_rounded,
          onTap: () {
            if (store.acceptProposal(match.id)) {
              showWaliSnack(
                context,
                'Proposal accepted — you are matched, barakallahu feekum',
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _StepButton(
          title: 'Send Message',
          subtitle: 'Opens once you accept the proposal',
          icon: Icons.chat_bubble_outline_rounded,
          ghost: true,
          onTap: () => showAppSnack(
            context,
            'Accept their proposal to open the chat.',
            icon: Icons.lock_outline_rounded,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            key: const Key('detail_decline'),
            onPressed: () {
              if (store.declineProposal(match.id)) {
                showAppSnack(context, 'Proposal declined respectfully.');
              }
            },
            child: Text(
              'Decline proposal',
              style: _t(12.5, FontWeight.w700, AppTheme.slate500),
            ),
          ),
        ),
      ];
    }
    if (shared) {
      return <Widget>[
        _StepButton(
          key: const Key('detail_chat'),
          title: 'Send Message',
          subtitle: 'Chaperoned chat with ${match.firstName}',
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => context.push(AppRoutes.chat(match.id)),
        ),
        const SizedBox(height: 10),
        PositiveOutlinedButton(
          key: const Key('detail_schedule'),
          label: 'Schedule a Family Call',
          icon: Icons.video_camera_front_outlined,
          gold: true,
          onPressed: () => context.push(AppRoutes.schedule(match.id)),
        ),
      ];
    }
    if (requested) {
      return <Widget>[
        Container(
          key: const Key('contact_pending_pill'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.warningBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.goldAccent.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.hourglass_top_rounded,
                size: 16,
                color: AppTheme.goldInk,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contact request pending — awaiting family approval',
                  style: _t(12, FontWeight.w800, AppTheme.goldInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Both families will be notified once your request is approved. '
          'Your Wali can follow up from the Wali hub.',
          style: AppTheme.bodySmall,
        ),
      ];
    }
    if (approved) {
      return <Widget>[
        _StepButton(
          key: const Key('detail_chat'),
          title: 'Send Message',
          subtitle: 'Chaperoned chat with ${match.firstName}',
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => context.push(AppRoutes.chat(match.id)),
        ),
        const SizedBox(height: 10),
        PositiveOutlinedButton(
          key: const Key('detail_request_contact'),
          label: 'Request Contact · 1 credit',
          icon: Icons.phone_in_talk_outlined,
          gold: true,
          onPressed: () => _requestContact(match),
        ),
      ];
    }
    if (proposed) {
      return <Widget>[
        _StepButton(
          key: const Key('proposal_sent_pill'),
          title: 'Proposal Sent',
          subtitle: 'Awaiting ${match.waliName}\'s response',
          icon: Icons.check_circle_rounded,
          muted: true,
          chevron: false,
          onTap: () => showAppSnack(
            context,
            'Your proposal is already with their family.',
            icon: Icons.favorite_rounded,
          ),
        ),
        const SizedBox(height: 10),
        PositiveOutlinedButton(
          key: const Key('detail_request_contact'),
          label: 'Request Contact · 1 credit',
          icon: Icons.phone_in_talk_outlined,
          gold: true,
          onPressed: () => _requestContact(match),
        ),
      ];
    }
    return <Widget>[
      _StepButton(
        key: const Key('detail_intro'),
        title: 'Send Proposal',
        subtitle: 'Ask ${match.waliName} for an introduction',
        icon: Icons.favorite_rounded,
        onTap: () => _sendProposal(match),
      ),
      const SizedBox(height: 10),
      PositiveOutlinedButton(
        key: const Key('detail_request_contact'),
        label: 'Request Contact · 1 credit',
        icon: Icons.phone_in_talk_outlined,
        gold: true,
        onPressed: () => _requestContact(match),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.favorite_rounded, size: 11, color: AppTheme.slate400),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${store.proposalsLeft} of 5 proposals left today · '
              '${store.contactCredits} gold credits',
              style: _t(10.5, FontWeight.w600, AppTheme.slate500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Center(
        child: TextButton.icon(
          key: const Key('detail_incompatible'),
          onPressed: () => _markIncompatible(match),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: Text(
            'Not a fit — hide from deck',
            style: _t(12, FontWeight.w700, AppTheme.slate500),
          ),
        ),
      ),
    ];
  }

  Widget _demGrid(List<(String, String)> cells) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: InfoTile(label: cells[i].$1, value: cells[i].$2),
                  ),
                  const SizedBox(width: 10),
                  if (i + 1 < cells.length)
                    Expanded(
                      child: InfoTile(
                        label: cells[i + 1].$1,
                        value: cells[i + 1].$2,
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One page of the detail photo carousel — quote overlay on the first slide.
class _PhotoSlide extends StatelessWidget {
  const _PhotoSlide({
    required this.match,
    required this.showQuote,
    required this.onOpen,
    this.slideKey,
  });

  final MatchProfile match;
  final bool showQuote;
  final VoidCallback onOpen;
  final Key? slideKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: slideKey,
      onTap: onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppNetworkImage(url: match.imageUrl),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: showQuote
                      ? const <double>[0, 0.45, 0.72]
                      : const <double>[0, 0.22, 0.4],
                  colors: <Color>[
                    AppTheme.emeraldDeep
                        .withValues(alpha: showQuote ? 0.9 : 0.45),
                    AppTheme.emeraldDeep
                        .withValues(alpha: showQuote ? 0.4 : 0.18),
                    AppTheme.emeraldDeep.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          if (showQuote)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 28,
                    color: AppTheme.mint,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${match.marriageQuote}"',
                    style: AppTheme.ts(
                      12.5,
                      FontWeight.w600,
                      color: AppTheme.ivory,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const Expanded(child: _StorySegment(active: true)),
                      const SizedBox(width: 4),
                      const Expanded(child: _StorySegment()),
                      const SizedBox(width: 4),
                      const Expanded(child: _StorySegment()),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Thin story-progress segment under the quote overlay.
class _StorySegment extends StatelessWidget {
  const _StorySegment({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: active ? AppTheme.mint : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Carousel pagination dot.
class _CarouselDot extends StatelessWidget {
  const _CarouselDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 6 : 5,
      height: active ? 6 : 5,
      decoration: BoxDecoration(
        color: active
            ? AppTheme.mint
            : Colors.white.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Small crest circle pinned to the photo top-left.
class _MiniCrest extends StatelessWidget {
  const _MiniCrest();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.goldAccent, width: 1.6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.mosque_rounded,
        size: 18,
        color: AppTheme.green,
      ),
    );
  }
}

/// Full-width stacked step button of the "TAKE THE NEXT STEP" section.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.ghost = false,
    this.chevron = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;
  final bool ghost;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final Color background = ghost
        ? Colors.white
        : (muted ? AppTheme.successBg : AppTheme.green);
    final Color foreground = ghost
        ? AppTheme.slate900
        : (muted ? AppTheme.success : Colors.white);
    final Color subColor = foreground.withValues(alpha: 0.78);
    final Color iconBackground = ghost
        ? AppTheme.mint.withValues(alpha: 0.35)
        : (muted ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final Color iconColor = ghost
        ? AppTheme.emerald
        : (muted ? AppTheme.success : Colors.white);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: ghost
            ? BorderSide(color: AppTheme.slate200)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: _t(15, FontWeight.w800, foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _t(11.5, FontWeight.w600, subColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (chevron) ...<Widget>[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: foreground.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill chip shown in the profile header.
class _CoverPill extends StatelessWidget {
  const _CoverPill(this.label, {this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.gold : AppTheme.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight
              ? AppTheme.goldAccent.withValues(alpha: 0.7)
              : AppTheme.slate200,
        ),
      ),
      child: Text(
        label,
        style: _t(
          10.5,
          FontWeight.w800,
          highlight ? AppTheme.goldInk : AppTheme.slate700,
        ),
      ),
    );
  }
}

/// Revealed contact card shown once both families approve.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.match});

  final MatchProfile match;

  @override
  Widget build(BuildContext context) {
    final int n = match.id.hashCode.abs() % 90 + 10;
    return AppCard(
      key: const Key('contact_revealed_card'),
      backgroundColor: AppTheme.warningBg,
      borderColor: AppTheme.goldAccent.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppTheme.goldInk,
              ),
              const SizedBox(width: 7),
              Text(
                'CONTACT SHARED',
                style: _t(10, FontWeight.w800, AppTheme.goldInk).copyWith(
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: '+44 7700 900$n',
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: '${match.firstName.toLowerCase()}.family@nikah.demo',
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.shield_outlined,
            label: 'Wali',
            value: match.waliName,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: AppTheme.goldDeep),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(label, style: _t(12, FontWeight.w600, AppTheme.slate600)),
        ),
        Expanded(
          child: Text(
            value,
            style: _t(12.5, FontWeight.w800, AppTheme.slate900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bullet rows for the religious-practice list.
class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.practices});

  final List<String> practices;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < practices.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      practices[i],
                      style: _t(13, FontWeight.w500, AppTheme.slate700),
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

/// Guardian (Wali) summary card with verification pill and routing note.
class _GuardianCard extends StatelessWidget {
  const _GuardianCard({required this.match});

  final MatchProfile match;

  @override
  Widget build(BuildContext context) {
    final bool verified = match.isWaliVerified;
    final Color pillFg = verified ? AppTheme.success : AppTheme.warning;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.ivoryWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.goldAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppTheme.goldDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      match.waliName,
                      style: _t(14, FontWeight.w800, AppTheme.slate900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Wali · ${match.waliRelation}',
                      style: _t(12, FontWeight.w500, AppTheme.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: verified ? AppTheme.successBg : AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pillFg.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      verified
                          ? Icons.verified_user_outlined
                          : Icons.hourglass_top_rounded,
                      size: 12,
                      color: pillFg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      verified ? 'Wali verified' : 'Verification pending',
                      style: _t(10.5, FontWeight.w800, pillFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Contact routed through your Wali — direct messaging opens only '
            'after their sign-off.',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

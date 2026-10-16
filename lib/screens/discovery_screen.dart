// Discovery tab — Barkat-style "Introductions for you" deck with the
// Incompatible / Send Proposal / Request Contact action row.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_brand.dart';
import '../widgets/app_images.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

/// Discovery deck tab of the home shell.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Slide the deck to the next card after an action removes the current one.
  void _advanceCard(int removedIndex, int remainingCount) {
    if (!mounted || remainingCount == 0 || !_pageController.hasClients) return;
    final int target = removedIndex >= remainingCount
        ? remainingCount - 1
        : removedIndex;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _sendProposal(MatchProfile profile, int index) {
    final AppStore store = context.read<AppStore>();
    final bool ok = store.sendProposal(profile.id);
    if (!ok) {
      showAppSnack(
        context,
        'Daily limit reached — ${AppStore.proposalQuota}/${AppStore.proposalQuota} '
        'proposals sent. More slots unlock tomorrow.',
        icon: Icons.hourglass_bottom_rounded,
        background: AppTheme.goldDeep,
      );
      return;
    }
    showSuccessSnack(
      context,
      'Proposal sent — ${profile.firstName}\'s family was notified.',
    );
    _advanceCard(index, store.discoveredProfiles.length);
  }

  void _requestContact(MatchProfile profile, int index) {
    final AppStore store = context.read<AppStore>();
    final bool ok = store.requestContact(profile.id);
    if (!ok) {
      showAppSnack(
        context,
        'Out of contact credits — top up from the Premium tab.',
        icon: Icons.diamond_outlined,
        background: AppTheme.goldDeep,
      );
      return;
    }
    showWaliSnack(context, 'Contact request sent to ${profile.firstName}');
    _advanceCard(index, store.discoveredProfiles.length);
  }

  void _markIncompatible(MatchProfile profile, int index) {
    final AppStore store = context.read<AppStore>();
    store.markIncompatible(profile.id);
    showAppSnack(
      context,
      'Marked incompatible — we will show more like your preferences.',
      icon: Icons.close_rounded,
    );
    _advanceCard(index, store.discoveredProfiles.length);
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<MatchProfile> profiles = store.discoveredProfiles;
    final String firstName =
        store.profile?.displayName.split(' ').firstOrNull ?? 'there';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BarkatLogoMark(size: 30),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                'Barkat Nikah',
                style: AppTheme.ts(16.5, FontWeight.w800, color: AppTheme.slate900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          NotificationBell(
            unread: store.unreadNotificationCount,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            key: const Key('discovery_open_filters'),
            tooltip: 'Search & Filters',
            onPressed: () => context.push(AppRoutes.filters),
            icon: Badge.count(
              isLabelVisible: store.filters.activeCount > 0,
              backgroundColor: AppTheme.green,
              textStyle: AppTheme.ts(9, FontWeight.w800, color: AppTheme.ivory),
              count: store.filters.activeCount,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Assalamu Alaikum, $firstName 👋',
                  style: AppTheme.ts(14, FontWeight.w600, color: AppTheme.slate500),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            const TextSpan(text: 'Introductions '),
                            TextSpan(
                              text: 'for you',
                              style: AppTheme.ts(
                                23,
                                FontWeight.w800,
                                color: AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                        style: AppTheme.ts(
                          23,
                          FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ProposalsPill(
                      used: store.proposalsSentToday,
                      quota: AppStore.proposalQuota,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: profiles.isEmpty
                ? EmptyState(
                    icon: Icons.explore_off_rounded,
                    title: 'All reviewed',
                    body: 'Every profile matching your preferences has been '
                        'considered. Broaden your search to keep browsing.',
                    actionLabel: 'Adjust Filters',
                    onAction: () => context.push(AppRoutes.filters),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: profiles.length,
                    itemBuilder: (BuildContext context, int index) => _DeckCard(
                      profile: profiles[index],
                      matchPercent: profiles[index].matchPercent,
                      onIncompatible: () =>
                          _markIncompatible(profiles[index], index),
                      onProposal: () => _sendProposal(profiles[index], index),
                      onContact: () => _requestContact(profiles[index], index),
                      onExplore: () =>
                          context.push(AppRoutes.matchDetail(profiles[index].id)),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// "0/5 PROPOSALS SENT" counter pill in the header.
class _ProposalsPill extends StatelessWidget {
  const _ProposalsPill({required this.used, required this.quota});

  final int used;
  final int quota;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$used/$quota',
                style: AppTheme.ts(12.5, FontWeight.w800, color: AppTheme.slate900),
              ),
              Text(
                'PROPOSALS SENT',
                style: AppTheme.ts(
                  7.5,
                  FontWeight.w700,
                  color: AppTheme.slate500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One full-bleed introduction card with the three Barkat actions.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.profile,
    required this.matchPercent,
    required this.onIncompatible,
    required this.onProposal,
    required this.onContact,
    required this.onExplore,
  });

  final MatchProfile profile;
  final int matchPercent;
  final VoidCallback onIncompatible;
  final VoidCallback onProposal;
  final VoidCallback onContact;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final String educationLine = profile.university.isNotEmpty
        ? profile.university
        : profile.education;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        key: Key('discovery_card_${profile.id}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.goldAccent.withValues(alpha: 0.55),
            width: 1.6,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.slate900.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: AppNetworkImage(url: profile.imageUrl)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const <double>[0, 0.42, 0.78],
                      colors: <Color>[
                        const Color(0xFF101613).withValues(alpha: 0.92),
                        const Color(0xFF101613).withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(top: 14, left: 14, child: _CrestBadge()),
              if (profile.isNew)
                const Positioned(top: 14, right: 14, child: _NewProfilePill()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (profile.isSelfManaged) ...<Widget>[
                        const _SelfManagedPill(),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${profile.name}, ${profile.age}',
                              style: AppTheme.ts(
                                22,
                                FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (matchPercent > 0) ...<Widget>[
                            const SizedBox(width: 10),
                            _MatchRing(percent: matchPercent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      _InfoRow(
                        icon: Icons.work_outline_rounded,
                        text: profile.profession,
                      ),
                      if (educationLine.isNotEmpty)
                        _InfoRow(
                          icon: Icons.school_outlined,
                          text: educationLine,
                        ),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: profile.location,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          _DeckChip(
                            label: profile.caste,
                            icon: Icons.groups_2_outlined,
                          ),
                          _DeckChip(
                            label: profile.maritalStatus,
                            icon: Icons.favorite_border_rounded,
                          ),
                          _DeckChip(
                            label: profile.height.split(' ').first,
                            icon: Icons.height_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppTheme.mint,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: 'Marriage',
                                    style: AppTheme.ts(
                                      12.5,
                                      FontWeight.w700,
                                      color: AppTheme.mint,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' : ${profile.marriageReadiness}'
                                        .replaceFirst('Ready', ''),
                                    style: AppTheme.ts(
                                      12.5,
                                      FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Flexible(
                            child: _CircleAction(
                              key: Key('discovery_pass_${profile.id}'),
                              label: 'Incompatible',
                              background: Colors.white,
                              iconColor: AppTheme.danger,
                              icon: Icons.close_rounded,
                              onTap: onIncompatible,
                            ),
                          ),
                          Flexible(
                            child: _CircleAction(
                              key: Key('discovery_intro_${profile.id}'),
                              label: 'Send Proposal',
                              background: AppTheme.green,
                              iconColor: Colors.white,
                              icon: Icons.favorite_rounded,
                              size: 74,
                              ringed: true,
                              onTap: onProposal,
                            ),
                          ),
                          Flexible(
                            child: _CircleAction(
                              key: Key('discovery_contact_${profile.id}'),
                              label: 'Request Contact',
                              background: AppTheme.goldAccent,
                              iconColor: Colors.white,
                              icon: Icons.phone_rounded,
                              onTap: onContact,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        child: InkWell(
                          key: const Key('discovery_explore_next'),
                          onTap: onExplore,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Explore next profile',
                                  style: AppTheme.ts(
                                    12.5,
                                    FontWeight.w800,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppTheme.gold,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}

/// Gold crest circle pinned to the top-left of the card photo.
class _CrestBadge extends StatelessWidget {
  const _CrestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.goldAccent, width: 2),
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
        size: 20,
        color: AppTheme.green,
      ),
    );
  }
}

/// "✨ New Profile" gold pill.
class _NewProfilePill extends StatelessWidget {
  const _NewProfilePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.gold,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.auto_awesome_rounded, size: 11, color: AppTheme.goldInk),
          const SizedBox(width: 4),
          Text(
            'New Profile',
            style: AppTheme.ts(10.5, FontWeight.w800, color: AppTheme.goldInk),
          ),
        ],
      ),
    );
  }
}

/// "Self managed" dark pill above the name.
class _SelfManagedPill extends StatelessWidget {
  const _SelfManagedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.person_rounded, size: 11, color: AppTheme.mint),
          const SizedBox(width: 4),
          Text(
            'Self managed',
            style: AppTheme.ts(10, FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Circular "% MATCH" progress ring.
class _MatchRing extends StatelessWidget {
  const _MatchRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF101613).withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              strokeWidth: 3.5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mint),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$percent%',
                style: AppTheme.ts(12, FontWeight.w800, color: Colors.white),
              ),
              Text(
                'MATCH',
                style: AppTheme.ts(
                  6.5,
                  FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White info row with a light-green icon (profession / education / city).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.mint),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: AppTheme.ts(
                12.5,
                FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark translucent chip with a light-green icon.
class _DeckChip extends StatelessWidget {
  const _DeckChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: AppTheme.mint),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.ts(11, FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Round action button of the deck with its label underneath: white ✕,
/// green ♥ (ringed), gold 📞.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.label,
    required this.background,
    required this.iconColor,
    required this.icon,
    required this.onTap,
    this.size = 58,
    this.ringed = false,
  });

  final String label;
  final Color background;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final Widget circle = Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppTheme.slate900.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: ringed ? 30 : 24, color: iconColor),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ringed
            ? Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.mint.withValues(alpha: 0.65),
                    width: 2.5,
                  ),
                ),
                child: circle,
              )
            : circle,
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.ts(
            10.5,
            FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
      ],
    );
  }
}

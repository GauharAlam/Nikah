// Matches tab — Barkat-style deck: Match Mode toggle, Shared Contacts /
// Chat Matches pills, swipeable match cards with Message / Unmatch actions.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_images.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

/// Local shorthand for theme text styles inside this screen.
TextStyle _t(double size, FontWeight weight, [Color? color]) =>
    AppTheme.ts(size, weight, color: color ?? AppTheme.slate800);

/// Which deck the matches screen is showing.
enum _MatchMode { chats, contacts }

/// Matches hub — swipeable decks of chat matches and shared contacts.
class MatchesHubScreen extends StatefulWidget {
  const MatchesHubScreen({super.key});

  @override
  State<MatchesHubScreen> createState() => _MatchesHubScreenState();
}

class _MatchesHubScreenState extends State<MatchesHubScreen> {
  _MatchMode _mode = _MatchMode.chats;
  final PageController _deckController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  void _setMode(_MatchMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _page = 0;
    });
    if (_deckController.hasClients) {
      _deckController.jumpToPage(0);
    }
  }

  void _unmatch(MatchProfile profile) {
    context.read<AppStore>().unmatch(profile.id);
    showAppSnack(
      context,
      '${profile.firstName} was removed from your matches.',
      icon: Icons.heart_broken_outlined,
    );
    final int remaining = _mode == _MatchMode.chats
        ? context.read<AppStore>().chatMatches.length
        : context.read<AppStore>().sharedContactProfiles.length;
    if (!_deckController.hasClients || remaining == 0) return;
    final int target = _page >= remaining ? remaining - 1 : _page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_deckController.hasClients) return;
      _deckController.jumpToPage(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<MatchProfile> chats = store.chatMatches;
    final List<MatchProfile> contacts = store.sharedContactProfiles;
    final List<MatchProfile> deck =
        _mode == _MatchMode.chats ? chats : contacts;
    final bool isChats = _mode == _MatchMode.chats;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Matches',
                      style: _t(26, FontWeight.w800, AppTheme.slate900),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'MATCH MODE',
                        style: _t(9, FontWeight.w800, AppTheme.slate500)
                            .copyWith(letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 5),
                      _ModeToggle(
                        mode: _mode,
                        onChanged: _setMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
              child: Text(
                'Manage your matches here',
                style: _t(12.5, FontWeight.w600, AppTheme.slate500),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ModePill(
                      key: const Key('matches_mode_contacts'),
                      label: 'Shared Contacts',
                      icon: Icons.phone_in_talk_outlined,
                      count: contacts.length,
                      selected: !isChats,
                      onTap: () => _setMode(_MatchMode.contacts),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModePill(
                      key: const Key('matches_mode_chats'),
                      label: 'Chat Matches',
                      icon: Icons.chat_bubble_outline_rounded,
                      count: chats.length,
                      selected: isChats,
                      onTap: () => _setMode(_MatchMode.chats),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    isChats ? 'Chat Matches' : 'Shared Contacts',
                    style: _t(18, FontWeight.w800, AppTheme.slate900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${deck.length}',
                    style: _t(11.5, FontWeight.w800, AppTheme.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Center(
              child: Text(
                isChats
                    ? 'In-app matches before sharing contact details.'
                    : 'Contact details exchanged between both families.',
                textAlign: TextAlign.center,
                style: _t(12, FontWeight.w500, AppTheme.slate500),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: deck.isEmpty
                  ? (isChats
                        ? EmptyState(
                            icon: Icons.forum_outlined,
                            title: 'No chat matches yet',
                            body: 'Approve an introduction to open a '
                                'chaperoned chat — it will appear here.',
                            actionLabel: 'Browse Discovery',
                            onAction: () => context.go(AppRoutes.homeDiscovery),
                          )
                        : EmptyState(
                            icon: Icons.phone_disabled_outlined,
                            title: 'No shared contacts yet',
                            body: 'Contact details appear here once both '
                                'families approve a request.',
                            actionLabel: 'Review Requests',
                            onAction: () => context.go(AppRoutes.homeProposals),
                          ))
                  : PageView.builder(
                      controller: _deckController,
                      onPageChanged: (int i) => setState(() => _page = i),
                      itemCount: deck.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _MatchDeckCard(
                        key: Key('match_deck_${deck[index].id}'),
                        profile: deck[index],
                        unread: store.unreadCount(deck[index].id),
                        onMessage: () =>
                            context.push(AppRoutes.chat(deck[index].id)),
                        onUnmatch: () => _unmatch(deck[index]),
                        onOpen: () =>
                            context.push(AppRoutes.matchDetail(deck[index].id)),
                      ),
                    ),
            ),
            if (deck.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < deck.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          width: i == _page ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppTheme.green
                                : AppTheme.slate300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Two-icon capsule switch mirroring the Barkat "Match Mode" toggle.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _MatchMode mode;
  final ValueChanged<_MatchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ModeToggleIcon(
            icon: Icons.chat_bubble_rounded,
            active: mode == _MatchMode.chats,
            onTap: () => onChanged(_MatchMode.chats),
          ),
          _ModeToggleIcon(
            icon: Icons.favorite_rounded,
            active: mode == _MatchMode.contacts,
            onTap: () => onChanged(_MatchMode.contacts),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleIcon extends StatelessWidget {
  const _ModeToggleIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppTheme.green : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 15,
            color: active ? Colors.white : AppTheme.slate500,
          ),
        ),
      ),
    );
  }
}

/// Selector pill: "Shared Contacts" / "Chat Matches · count".
class _ModePill extends StatelessWidget {
  const _ModePill({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 15,
            color: selected ? Colors.white : AppTheme.slate600,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: _t(
                12.5,
                FontWeight.w800,
                selected ? Colors.white : AppTheme.slate800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...<Widget>[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? AppTheme.ivory : AppTheme.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: _t(
                  10.5,
                  FontWeight.w800,
                  selected ? AppTheme.green : AppTheme.slate700,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: selected ? AppTheme.green : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: selected
            ? BorderSide.none
            : BorderSide(color: AppTheme.slate200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// One swipeable match card with photo, facts, quote and Message / Unmatch.
class _MatchDeckCard extends StatelessWidget {
  const _MatchDeckCard({
    super.key,
    required this.profile,
    required this.unread,
    required this.onMessage,
    required this.onUnmatch,
    required this.onOpen,
  });

  final MatchProfile profile;
  final int unread;
  final VoidCallback onMessage;
  final VoidCallback onUnmatch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String educationLine = profile.university.isNotEmpty
        ? profile.university
        : profile.education;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.slate900.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: AppNetworkImage(url: profile.imageUrl)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const <double>[0, 0.46, 0.8],
                        colors: <Color>[
                          const Color(0xFF101613).withValues(alpha: 0.93),
                          const Color(0xFF101613).withValues(alpha: 0.48),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      key: Key('unread_chip_${profile.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unread new',
                        style: _t(10, FontWeight.w800, AppTheme.emeraldDeep),
                      ),
                    ),
                  ),
                if (profile.isNew)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: AppTheme.goldInk,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New Profile',
                            style: _t(10.5, FontWeight.w800, AppTheme.goldInk),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A)
                                  .withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.person_rounded,
                                  size: 11,
                                  color: AppTheme.mint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Self managed',
                                  style: _t(10, FontWeight.w700, Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: '${profile.name}, ',
                                      style: _t(22, FontWeight.w800, Colors.white),
                                    ),
                                    TextSpan(
                                      text: '${profile.age}',
                                      style: _t(22, FontWeight.w800, AppTheme.mint),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.ivory.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${profile.matchPercent}% match',
                                style: _t(9.5, FontWeight.w800, AppTheme.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _DeckInfoRow(
                          icon: Icons.work_outline_rounded,
                          text: profile.profession,
                        ),
                        if (educationLine.isNotEmpty)
                          _DeckInfoRow(
                            icon: Icons.school_outlined,
                            text: educationLine,
                          ),
                        _DeckInfoRow(
                          icon: Icons.location_on_outlined,
                          text: profile.location,
                        ),
                        const SizedBox(height: 8),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.format_quote_rounded,
                              size: 16,
                              color: AppTheme.mint,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '"${profile.marriageQuote}"',
                                style: _t(
                                  11.5,
                                  FontWeight.w600,
                                  Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _DeckButton(
                                key: Key('match_msg_${profile.id}'),
                                label: 'Message',
                                icon: Icons.chat_bubble_outline_rounded,
                                background: AppTheme.green,
                                foreground: Colors.white,
                                onTap: onMessage,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DeckButton(
                                key: Key('match_unmatch_${profile.id}'),
                                label: 'Unmatch',
                                icon: Icons.close_rounded,
                                iconColor: AppTheme.danger,
                                background: AppTheme.ivoryWarm,
                                foreground: AppTheme.slate800,
                                onTap: onUnmatch,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded Message / Unmatch button inside the match deck card.
class _DeckButton extends StatelessWidget {
  const _DeckButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: background == AppTheme.ivoryWarm
            ? BorderSide(color: AppTheme.slate200)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: iconColor ?? foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: _t(12.5, FontWeight.w800, foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White info row with a light-green icon inside the match card.
class _DeckInfoRow extends StatelessWidget {
  const _DeckInfoRow({required this.icon, required this.text});

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
              style: _t(
                12.5,
                FontWeight.w600,
                Colors.white.withValues(alpha: 0.92),
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
          Text(label, style: _t(11, FontWeight.w600, Colors.white)),
        ],
      ),
    );
  }
}

// Private widgets backing the chaperoned chat experience.

part of 'chat_screen.dart';

/// Emerald supervision strip rendered directly under the app bar.
class _ChaperoneHeader extends StatelessWidget {
  const _ChaperoneHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: const BoxDecoration(gradient: AppTheme.brandWash),
      child: Row(
        children: <Widget>[
          Expanded(child: ChaperoneBadge(text: text)),
          const SizedBox(width: 10),
          const Icon(Icons.shield_outlined, size: 13, color: AppTheme.gold),
        ],
      ),
    );
  }
}

/// Gold quote strip shown while the thread is still small (seed stage).
class _HadithQuoteStrip extends StatelessWidget {
  const _HadithQuoteStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.format_quote_rounded,
            size: 15,
            color: AppTheme.goldAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '"A good word is charity." — The Prophet Muhammad ﷺ '
              '(Bukhari & Muslim)',
              style: AppTheme.ts(
                11.5,
                FontWeight.w600,
                color: AppTheme.goldInk,
                height: 1.4,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tap-to-insert icebreaker chips; nothing is sent automatically.
class _IcebreakerChips extends StatelessWidget {
  const _IcebreakerChips({required this.onPick});

  final ValueChanged<String> onPick;

  static const List<String> _phrases = <String>[
    'MashaAllah',
    'In sha Allah',
    'Jazak Allah khayr',
    'My Wali will contact yours',
    'Barakallahu fikum',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _phrases.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) =>
            _IcebreakerChip(phrase: _phrases[index], onPick: onPick),
      ),
    );
  }
}

class _IcebreakerChip extends StatelessWidget {
  const _IcebreakerChip({required this.phrase, required this.onPick});

  final String phrase;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(phrase),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Text(
          phrase,
          style: AppTheme.ts(12, FontWeight.w700, color: AppTheme.green),
        ),
      ),
    );
  }
}

/// Bottom composer: expanding text field + emerald send button.
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: Key('chat_input'),
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppTheme.ts(
                14.5,
                FontWeight.w600,
                color: AppTheme.slate900,
              ),
              decoration: InputDecoration(
                hintText: 'Write with ihsan…',
                hintStyle: AppTheme.ts(
                  13.5,
                  FontWeight.w500,
                  color: AppTheme.slate400,
                ),
                filled: true,
                fillColor: AppTheme.slate100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            key: Key('chat_send'),
            behavior: HitTestBehavior.opaque,
            onTap: canSend ? onSend : null,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canSend ? AppTheme.emerald : AppTheme.slate300,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 19,
                color: canSend ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rendered variant for each [MessageSender] with a per-message key.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showSeen});

  final ChatMessage message;
  final bool showSeen;

  @override
  Widget build(BuildContext context) {
    return switch (message.sender) {
      MessageSender.user => _userBubble(context),
      MessageSender.match => _matchBubble(context),
      MessageSender.chaperone => _chaperoneShell(context),
      MessageSender.system => _systemPill(context),
    };
  }

  Widget _userBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: Key('chat_bubble_${message.id}'),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.emerald,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              message.text,
              style: AppTheme.ts(
                13.5,
                FontWeight.w500,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.time,
              style: AppTheme.ts(10, FontWeight.w500, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchBubble(BuildContext context) {
    final Widget bubble = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: Key('chat_bubble_${message.id}'),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              message.text,
              style: AppTheme.ts(
                13.5,
                FontWeight.w500,
                color: AppTheme.slate900,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.time,
              style: AppTheme.ts(10, FontWeight.w500, color: AppTheme.slate400),
            ),
          ],
        ),
      ),
    );

    if (!showSeen) return bubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        bubble,
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 2),
          child: Text(
            'Seen ✓✓ by Wali',
            style: AppTheme.ts(10, FontWeight.w600, color: AppTheme.slate400),
          ),
        ),
      ],
    );
  }

  Widget _chaperoneShell(BuildContext context) {
    return Container(
      key: Key('chat_bubble_${message.id}'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(color: AppTheme.slate100),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: AppTheme.slate500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: AppTheme.ts(
                12,
                FontWeight.w500,
                color: AppTheme.slate500,
                height: 1.4,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            message.time,
            style: AppTheme.ts(9.5, FontWeight.w500, color: AppTheme.slate400),
          ),
        ],
      ),
    );
  }

  Widget _systemPill(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: Key('chat_bubble_${message.id}'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                message.text,
                style: AppTheme.ts(
                  11,
                  FontWeight.w700,
                  color: AppTheme.goldDeep,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message.time,
              style: AppTheme.ts(
                10,
                FontWeight.w500,
                color: AppTheme.goldDeep.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-to-one conversation with a match.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../config/app_config.dart';
import '../services/scam_detector.dart';
import '../models/chat_message.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';

part 'chat_screen_parts.dart';

/// Sends are safe to build against the seed length; once the thread grows
/// beyond it, the hadith quote strip is retired.
const int _seedMessageCount = 4;

/// Full chat screen for one [MatchProfile], showing messages from
/// [AppStore.messages], quick icebreakers and a supervised input bar.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  int _seenCount = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AppStore store = context.read<AppStore>();
      store.markThreadRead(widget.matchId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend => _textController.text.trim().isNotEmpty;

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  // Rebuilds on any store change cause this to run; when the thread grows
  // (send or auto-reply), jump to bottom and clear the unread badge.
  void _listenForNewMessages(List<ChatMessage> messages) {
    if (messages.length == _seenCount) return;
    _seenCount = messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToBottomNow();
      context.read<AppStore>().markThreadRead(widget.matchId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToBottomNow();
    });
  }

  void _jumpToBottomNow() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _insertIcebreaker(String phrase) {
    final String base = _textController.text;
    _textController.text = base.isEmpty ? '$phrase ' : '$base $phrase';
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _focusNode.requestFocus();
  }

  void _sendMessage() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<AppStore>().sendMessage(widget.matchId, text);
    _textController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final MatchProfile match = store.profileById(widget.matchId);
    final List<ChatMessage> messages = store.messages(widget.matchId);
    _listenForNewMessages(messages);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 8,
        title: Row(
          children: <Widget>[
            AppAvatar(
              url: match.imageUrl,
              radius: 16,
              initials: match.firstName.isEmpty
                  ? '?'
                  : match.firstName.substring(0, 1).toUpperCase(),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          match.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.ts(
                            15.5,
                            FontWeight.w800,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('open_journey'),
            tooltip: 'Nikah Journey',
            icon: const Icon(Icons.route_outlined, size: 22),
            onPressed: () => context.push(AppRoutes.journey(widget.matchId)),
          ),
          IconButton(
            tooltip: 'View ${match.firstName}\'s profile',
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            onPressed: () =>
                context.push(AppRoutes.matchDetail(widget.matchId)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            if (AppConfig.guardianFeatures)
              _ChaperoneHeader(
                text: 'Supervised by ${store.guardian.name} & ${match.waliName}',
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final ChatMessage message = messages[index];
                  return _MessageBubble(
                    message: message,
                    showSeen:
                        message.sender == MessageSender.match &&
                        store.privacy('readReceipts'),
                  );
                },
              ),
            ),
            if (ScamDetector.threadIsRisky(messages))
              const _ScamWarning()
            else if (messages.length <= _seedMessageCount)
              const _HadithQuoteStrip(),
            _IcebreakerChips(onPick: _insertIcebreaker),
            _ChatInputBar(
              controller: _textController,
              focusNode: _focusNode,
              canSend: _canSend,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

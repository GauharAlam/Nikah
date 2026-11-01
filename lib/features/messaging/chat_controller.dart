import 'dart:async';

import '../../data/backend.dart';
import '../../models/chat_message.dart';
import '../../models/nikah_journey.dart';
import '../core/feature_controller.dart';
import '../discovery/discovery_controller.dart';
import '../session/session_controller.dart';

/// Matches, the open conversation, and the shared Nikah Journey.
///
/// The match list comes from one bounded stream. Messages stream only while a
/// conversation is on screen, so twenty matches never mean twenty listeners.
class ChatController extends FeatureController {
  ChatController(super.backend, super.report, this._session, this._discovery);

  final SessionController _session;
  final DiscoveryController _discovery;

  Map<String, MatchThread> _threads = <String, MatchThread>{};
  Set<String> _open = <String>{};

  String? _activeId;
  StreamSubscription<List<ChatMessage>>? _activeSub;
  List<ChatMessage> _live = <ChatMessage>[];
  List<ChatMessage> _older = <ChatMessage>[];
  List<ChatMessage> _outbox = <ChatMessage>[];
  bool _reachedStart = false;
  bool _loadingOlder = false;
  int _seq = 0;

  /// Members this member has an open match with.
  Set<String> get openMatches => _open;
  bool isMatched(String id) => _open.contains(id);
  bool get reachedStart => _reachedStart;
  bool get isLoadingOlder => _loadingOlder;

  /// Ended relationships, for the history view.
  List<String> get closedIds =>
      _threads.values.where((MatchThread t) => !t.isOpen).map((MatchThread t) => t.otherId).toList();

  void start(String uid) => follow(backend.watchMatches(uid), _onMatches);

  void _onMatches(List<MatchThread> threads) {
    _threads = <String, MatchThread>{for (final MatchThread t in threads) t.otherId: t};
    _open = threads.where((MatchThread t) => t.isOpen).map((MatchThread t) => t.otherId).toSet();
    unawaited(_discovery.ensure(_threads.keys));
    if (_activeId != null && !_open.contains(_activeId)) {
      _live = <ChatMessage>[];
      unawaited(_activeSub?.cancel());
      _activeSub = null;
    }
    notifyListeners();
  }

  // ─── Conversation lifecycle ──────────────────────────────────────────────

  /// Starts streaming the conversation with [id], when the match is open.
  void openThread(String id) {
    if (_activeId == id) return;
    closeThread();
    _activeId = id;
    final MatchThread? thread = _threads[id];
    if (thread == null || !thread.isOpen) return;
    _activeSub = backend.watchMessages(thread.pairId, _session.uid).listen((List<ChatMessage> m) {
      _live = m;
      final Set<String> arrived = m.map((ChatMessage x) => x.id).toSet();
      _outbox = _outbox.where((ChatMessage x) => !arrived.contains(x.id)).toList();
      notifyListeners();
    }, onError: report);
  }

  void closeThread() {
    unawaited(_activeSub?.cancel());
    _activeSub = null;
    _activeId = null;
    _live = <ChatMessage>[];
    _older = <ChatMessage>[];
    _outbox = <ChatMessage>[];
    _reachedStart = false;
  }

  Future<void> loadOlder() async {
    final MatchThread? thread = _threads[_activeId];
    if (thread == null || _loadingOlder || _reachedStart) return;
    final List<ChatMessage> shown = <ChatMessage>[..._older, ..._live];
    if (shown.isEmpty) return;
    _loadingOlder = true;
    notifyListeners();
    try {
      final List<ChatMessage> page =
          await backend.olderMessages(thread.pairId, _session.uid, shown.first.createdAt);
      _older = <ChatMessage>[...page, ..._older];
      _reachedStart = page.isEmpty;
    } on Object catch (e) {
      report(e);
    } finally {
      _loadingOlder = false;
      notifyListeners();
    }
  }

  // ─── Reading ─────────────────────────────────────────────────────────────

  List<String> get threadIds {
    final List<MatchThread> withMessages = _threads.values
        .where((MatchThread t) => t.isOpen && t.lastMessageAt != null)
        .where((MatchThread t) => !_discovery.isBlocked(t.otherId))
        .toList()
      ..sort((MatchThread a, MatchThread b) => b.lastMessageAt!.compareTo(a.lastMessageAt!));
    return withMessages.map((MatchThread t) => t.otherId).toList();
  }

  List<ChatMessage> messages(String id) => id == _activeId
      ? List<ChatMessage>.unmodifiable(<ChatMessage>[..._older, ..._live, ..._outbox])
      : const <ChatMessage>[];

  String preview(String id) {
    final String text = _threads[id]?.lastMessage ?? '';
    return text.isEmpty ? 'Say salam to begin your conversation' : text;
  }

  int unreadCount(String id) => _threads[id]?.unread ?? 0;

  int get totalUnread =>
      _threads.values.fold(0, (int sum, MatchThread t) => sum + t.unread);

  /// True once the other member has actually read [message].
  bool isSeen(String id, ChatMessage message) {
    final DateTime? read = _threads[id]?.theirReadAt;
    return read != null &&
        message.sender == MessageSender.user &&
        message.state == MessageState.sent &&
        !message.createdAt.isAfter(read);
  }

  void markRead(String id) {
    final MatchThread? thread = _threads[id];
    if (thread == null || !thread.isOpen || _session.user == null || thread.unread == 0) return;
    send(() => backend.markThreadRead(thread.pairId, _session.uid));
  }

  // ─── Sending ─────────────────────────────────────────────────────────────

  void sendMessage(String id, String text) {
    final String trimmed = text.trim();
    final MatchThread? thread = _threads[id];
    if (trimmed.isEmpty || thread == null || !thread.isOpen || _session.user == null) return;
    final DateTime now = DateTime.now();
    final ChatMessage message = ChatMessage(
      id: '${_session.uid}_${now.microsecondsSinceEpoch}_${_seq++}',
      text: trimmed,
      time: '',
      createdAt: now,
      sender: MessageSender.user,
      state: MessageState.sending,
    );
    _outbox = <ChatMessage>[..._outbox, message];
    notifyListeners();
    unawaited(_deliver(thread, message));
  }

  /// Sends again with the same id, so a retry can never duplicate a message.
  void retry(String id, String messageId) {
    final MatchThread? thread = _threads[id];
    final Iterable<ChatMessage> found = _outbox.where((ChatMessage m) => m.id == messageId);
    if (thread == null || found.isEmpty) return;
    _setState(messageId, MessageState.sending);
    unawaited(_deliver(thread, found.first));
  }

  void _setState(String messageId, MessageState state) {
    _outbox = _outbox
        .map((ChatMessage m) => m.id == messageId ? m.withState(state) : m)
        .toList();
    notifyListeners();
  }

  Future<void> _deliver(MatchThread thread, ChatMessage message) async {
    try {
      await backend.sendMessage(thread.pairId, _session.uid, message.text, id: message.id);
    } on Object {
      _setState(message.id, MessageState.failed);
    }
  }

  void unmatch(String id) => send(() => backend.unmatch(id));

  // ─── Nikah Journey ───────────────────────────────────────────────────────

  JourneyStep journeyStep(String id) =>
      JourneyStep.values.asNameMap()[_threads[id]?.myStep] ?? JourneyStep.talking;

  JourneyStep? theirJourneyStep(String id) =>
      JourneyStep.values.asNameMap()[_threads[id]?.theirStep];

  void setJourneyStep(String id, JourneyStep step) {
    final MatchThread? thread = _threads[id];
    if (thread != null && _session.user != null) {
      send(() => backend.setJourneyStep(thread.pairId, _session.uid, step.name));
    }
  }

  Future<Map<String, String>> myAnswers(String id) async {
    final MatchThread? thread = _threads[id];
    if (thread == null || _session.user == null) return <String, String>{};
    return await backend.loadAnswers(thread.pairId, _session.uid) ?? <String, String>{};
  }

  Future<Map<String, String>?> theirAnswers(String id) async {
    final MatchThread? thread = _threads[id];
    return thread == null ? null : backend.loadAnswers(thread.pairId, id);
  }

  Future<void> saveAnswers(String id, Map<String, String> answers) async {
    final MatchThread? thread = _threads[id];
    if (thread != null && _session.user != null) {
      await backend.saveAnswers(thread.pairId, _session.uid, answers);
    }
  }

  @override
  Future<void> stop() async {
    await super.stop();
    closeThread();
    _threads = <String, MatchThread>{};
    _open = <String>{};
  }
}

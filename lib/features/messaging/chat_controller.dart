import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend.dart';
import '../../models/chat_message.dart';
import '../../models/nikah_journey.dart';
import '../core/feature_controller.dart';
import '../discovery/discovery_controller.dart';
import '../session/session_controller.dart';

/// Matches, their conversations, and the shared Nikah Journey.
class ChatController extends FeatureController {
  ChatController(super.backend, super.report, this._session, this._discovery, this._prefs);

  final SessionController _session;
  final DiscoveryController _discovery;
  final SharedPreferences _prefs;

  final Map<String, StreamSubscription<List<ChatMessage>>> _threadSubs =
      <String, StreamSubscription<List<ChatMessage>>>{};
  Map<String, MatchThread> _threads = <String, MatchThread>{};
  Map<String, List<ChatMessage>> _chats = <String, List<ChatMessage>>{};
  Map<String, DateTime> _readAt = <String, DateTime>{};
  Set<String> _open = <String>{};

  String get _readKey => 'bk_read_at_${_session.uid}';

  /// Members this member has an open match with.
  Set<String> get openMatches => _open;
  bool isMatched(String id) => _open.contains(id);

  void start(String uid) {
    final String? raw = _prefs.getString(_readKey);
    if (raw != null) {
      _readAt = (jsonDecode(raw) as Map<String, dynamic>).map<String, DateTime>(
        (String k, dynamic v) => MapEntry<String, DateTime>(
          k,
          DateTime.fromMillisecondsSinceEpoch(v as int),
        ),
      );
    }
    follow(backend.watchMatches(uid), _onMatches);
  }

  void _onMatches(List<MatchThread> threads) {
    _threads = <String, MatchThread>{for (final MatchThread t in threads) t.otherId: t};
    _open = threads.where((MatchThread t) => t.isOpen).map((MatchThread t) => t.otherId).toSet();
    unawaited(_discovery.ensure(_open));
    final String uid = _session.uid;
    for (final MatchThread t in threads.where((MatchThread t) => t.isOpen)) {
      _threadSubs.putIfAbsent(
        t.otherId,
        () => backend.watchMessages(t.pairId, uid).listen((List<ChatMessage> messages) {
          _chats = <String, List<ChatMessage>>{..._chats, t.otherId: messages};
          notifyListeners();
        }, onError: report),
      );
    }
    for (final MatchThread t in threads.where((MatchThread t) => !t.isOpen)) {
      unawaited(_threadSubs.remove(t.otherId)?.cancel());
      _chats = <String, List<ChatMessage>>{..._chats}..remove(t.otherId);
    }
    notifyListeners();
  }

  List<String> get threadIds {
    final Iterable<String> visible = _chats.keys
        .where((String id) => !_discovery.isBlocked(id) && _chats[id]!.isNotEmpty);
    final List<String> sorted = visible.toList()
      ..sort((String a, String b) =>
          _chats[b]!.last.createdAt.compareTo(_chats[a]!.last.createdAt));
    return sorted;
  }

  List<ChatMessage> messages(String id) =>
      List<ChatMessage>.unmodifiable(_chats[id] ?? const <ChatMessage>[]);

  String preview(String id) {
    final List<ChatMessage> thread = _chats[id] ?? const <ChatMessage>[];
    return thread.isEmpty ? 'Say salam to begin your conversation' : thread.last.text;
  }

  int unreadCount(String id) {
    final DateTime? read = _readAt[id];
    return (_chats[id] ?? const <ChatMessage>[])
        .where((ChatMessage m) => m.sender == MessageSender.match)
        .where((ChatMessage m) => read == null || m.createdAt.isAfter(read))
        .length;
  }

  int get totalUnread =>
      _chats.keys.fold(0, (int sum, String id) => sum + unreadCount(id));

  void markRead(String id) {
    _readAt = <String, DateTime>{..._readAt, id: DateTime.now()};
    unawaited(_prefs.setString(_readKey, jsonEncode(<String, int>{
      for (final MapEntry<String, DateTime> e in _readAt.entries)
        e.key: e.value.millisecondsSinceEpoch,
    })));
    notifyListeners();
    final MatchThread? thread = _threads[id];
    if (thread != null && _session.user != null) {
      send(() => backend.markThreadRead(thread.pairId, _session.uid));
    }
  }

  void sendMessage(String id, String text) {
    final String trimmed = text.trim();
    final MatchThread? thread = _threads[id];
    if (trimmed.isEmpty || thread == null || !thread.isOpen || _session.user == null) return;
    send(() => backend.sendMessage(thread.pairId, _session.uid, trimmed));
  }

  void unmatch(String id) => send(() => backend.unmatch(id));

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
    for (final StreamSubscription<List<ChatMessage>> s in _threadSubs.values) {
      await s.cancel();
    }
    _threadSubs.clear();
    _threads = <String, MatchThread>{};
    _chats = <String, List<ChatMessage>>{};
    _readAt = <String, DateTime>{};
    _open = <String>{};
  }
}

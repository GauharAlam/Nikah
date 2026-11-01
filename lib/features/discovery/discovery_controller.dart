import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend.dart';
import '../../models/filters.dart';
import '../../models/match_profile.dart';
import '../core/feature_controller.dart';
import '../session/session_controller.dart';

/// The introductions deck, filters, and a cache of profiles the server served.
class DiscoveryController extends FeatureController {
  DiscoveryController(super.backend, super.report, this._session, this._prefs);

  final SessionController _session;
  final SharedPreferences _prefs;

  final Map<String, MatchProfile> _cache = <String, MatchProfile>{};

  /// Photo links last an hour, so cards are refreshed before they expire.
  static const Duration _cardLife = Duration(minutes: 50);
  final Map<String, DateTime> _fetchedAt = <String, DateTime>{};
  final Set<String> _fetching = <String>{};
  Set<String> _blocked = <String>{};
  List<MatchProfile> _introductions = <MatchProfile>[];
  MatchFilters _filters = const MatchFilters();
  int? _cursor;
  bool _exhausted = false;
  bool _loading = false;
  String? _error;
  int? _freeLeft;
  int _freeLimit = 15;
  bool _limitReached = false;

  List<MatchProfile> get introductions => _introductions;
  List<MatchProfile> get directory => _cache.values.toList();
  MatchFilters get filters => _filters;
  bool get isLoading => _loading;
  String? get error => _error;
  int? get freeLeft => _session.isPremium ? null : _freeLeft;
  int get freeLimit => _freeLimit;
  bool get limitReached => !_session.isPremium && _limitReached;
  bool isBlocked(String id) => _blocked.contains(id);

  String get _filtersKey => 'bk_filters_${_session.uid}';

  void start() {
    final String? raw = _prefs.getString(_filtersKey);
    if (raw == null) return;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) _filters = MatchFilters.fromJson(decoded);
  }

  /// Fetches any profiles not cached yet. Only approved members can read them.
  Future<void> ensure(Iterable<String> ids) async {
    if (!_session.hasApprovedClaim) return;
    final List<String> missing = ids
        .where((String id) => (!_cache.containsKey(id) || _isStale(id)) && !_fetching.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _fetching.addAll(missing);
    try {
      for (final MatchProfile p in await backend.getProfiles(missing)) {
        _remember(p);
      }
      notifyListeners();
    } on Object catch (e) {
      report(e);
    } finally {
      _fetching.removeAll(missing);
    }
  }

  bool _isStale(String id) {
    final DateTime? at = _fetchedAt[id];
    return at == null || DateTime.now().difference(at) > _cardLife;
  }

  void _remember(MatchProfile p) {
    _cache[p.id] = p;
    _fetchedAt[p.id] = DateTime.now();
  }

  MatchProfile profileById(String id) {
    final MatchProfile? known = _cache[id];
    if (known == null || _isStale(id)) unawaited(ensure(<String>[id]));
    return known ?? MatchProfile.unknown(id);
  }

  /// Lists carry the primary photo only. Opening a profile fetches them all.
  Future<void> loadFull(String id) async {
    if (!_session.hasApprovedClaim) return;
    try {
      for (final MatchProfile p in await backend.getProfiles(<String>[id])) {
        _remember(p);
      }
      notifyListeners();
    } on Object catch (e) {
      report(e);
    }
  }

  Future<void> refresh() async {
    _introductions = <MatchProfile>[];
    _cursor = null;
    _exhausted = false;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || _exhausted || !_session.hasApprovedClaim) return;
    _loading = true;
    _error = null;
    // A screen starts this from initState, where notifying would throw.
    scheduleMicrotask(notifyListeners);
    try {
      final IntroductionPage page = await backend.fetchIntroductions(_filters, _cursor);
      final Set<String> seen = _introductions.map((MatchProfile p) => p.id).toSet();
      final List<MatchProfile> fresh =
          page.profiles.where((MatchProfile p) => seen.add(p.id)).toList();
      fresh.forEach(_remember);
      _introductions = <MatchProfile>[..._introductions, ...fresh];
      _cursor = page.cursor;
      _exhausted = page.cursor == null;
      _freeLeft = page.freeLeft;
      _freeLimit = page.freeLimit;
      _limitReached = page.limitReached;
    } on Object catch (e) {
      _error = e is BackendException ? e.message : 'Could not load introductions.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Takes a profile off the deck, topping the deck up when it runs low.
  void drop(String id) {
    _introductions = _introductions.where((MatchProfile p) => p.id != id).toList();
    if (_introductions.length < 3) unawaited(loadMore());
  }

  void setFilters(MatchFilters next) {
    _filters = next;
    unawaited(_prefs.setString(_filtersKey, jsonEncode(next.toJson())));
    notifyListeners();
    unawaited(refresh());
  }

  void markIncompatible(String id) {
    drop(id);
    notifyListeners();
    send(() => backend.hideProfile(id));
  }

  /// Hides the profile at once, and puts it back if the server refuses.
  Future<void> block(String id) async {
    final MatchProfile? card = _cache[id];
    _blocked = <String>{..._blocked, id};
    drop(id);
    notifyListeners();
    try {
      await backend.blockProfile(id);
    } on Object {
      _blocked = <String>{..._blocked}..remove(id);
      if (card != null) restore(card);
      notifyListeners();
      rethrow;
    }
  }

  /// Puts a card back after a failed action.
  void restore(MatchProfile card) {
    if (_introductions.any((MatchProfile p) => p.id == card.id)) return;
    _introductions = <MatchProfile>[card, ..._introductions];
    notifyListeners();
  }

  MatchProfile? cached(String id) => _cache[id];

  /// One page of search results. Leaves the deck untouched.
  Future<IntroductionPage> search({required String query, required bool nearby, int? cursor}) async {
    final IntroductionPage page = await backend.fetchIntroductions(
      _filters.copyWith(query: query),
      cursor,
      nearby: nearby,
    );
    page.profiles.forEach(_remember);
    return page;
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _cache.clear();
    _fetchedAt.clear();
    _blocked = <String>{};
    _introductions = <MatchProfile>[];
    _filters = const MatchFilters();
    _cursor = null;
    _exhausted = false;
    _freeLeft = null;
    _limitReached = false;
  }
}

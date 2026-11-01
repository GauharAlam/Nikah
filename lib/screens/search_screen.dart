import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_images.dart';
import '../widgets/empty_state.dart';

/// Search Rishtey: free-text search on top of the saved filters, with a
/// Suggestions and Nearby switch. Every result comes from the server.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  bool _nearby = false;
  bool _loading = true;
  String? _error;
  List<MatchProfile> _results = <MatchProfile>[];
  int? _cursor;
  bool _limitReached = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 200 && !_loading && _cursor != null) {
      unawaited(_load(reset: false));
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _results = <MatchProfile>[];
        _cursor = null;
      }
    });
    try {
      final IntroductionPage page = await context.read<AppStore>().searchProfiles(
            query: _query.text.trim(),
            nearby: _nearby,
            cursor: _cursor,
          );
      if (!mounted) return;
      final Set<String> seen = _results.map((MatchProfile p) => p.id).toSet();
      setState(() {
        _results = <MatchProfile>[
          ..._results,
          ...page.profiles.where((MatchProfile p) => seen.add(p.id)),
        ];
        _cursor = page.cursor;
        _limitReached = page.limitReached;
      });
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setNearby(bool on) async {
    final AppStore store = context.read<AppStore>();
    if (on && !(store.profile?.nearbyOptIn ?? false)) {
      final bool? agreed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(tr('Turn on nearby?')),
          content: Text(tr(
            'People who also turn this on can find you by your home city. '
            'We never use GPS for this, and your address is never shown. '
            'You can turn it off in Settings.',
          )),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Not now'))),
            FilledButton(
              key: const Key('nearby_agree'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Turn on')),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      store.updatePrivacy(nearbyOptIn: true);
    }
    setState(() => _nearby = on);
    await _load(reset: true);
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, key: const Key('search_error'), textAlign: TextAlign.center),
            TextButton(onPressed: () => _load(reset: true), child: Text(tr('Try again'))),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: tr('No profiles found'),
        body: _limitReached
            ? tr('You have seen all the profiles on the free plan.')
            : tr('Try a different search or clear some filters.'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        itemCount: _results.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int i) {
          final MatchProfile p = _results[i];
          return ListTile(
            key: Key('search_result_${p.id}'),
            leading: AppAvatar(
              url: p.photosHidden ? '' : p.imageUrl,
              radius: 22,
              initials: p.firstName.isEmpty ? '?' : p.firstName.substring(0, 1).toUpperCase(),
            ),
            title: Text('${p.firstName}, ${p.age}'),
            subtitle: Text(
              <String>[p.education, p.university, p.location].where((String s) => s.isNotEmpty).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: p.isVerified
                ? const Icon(Icons.verified_rounded, color: AppTheme.green, size: 18)
                : null,
            onTap: () => context.push(AppRoutes.matchDetail(p.id)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(tr('Search Rishtey')),
        actions: <Widget>[
          IconButton(
            tooltip: tr('Filters'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await context.push(AppRoutes.filters);
              if (mounted) await _load(reset: true);
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('search_input'),
              controller: _query,
              textInputAction: TextInputAction.search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: tr('University, profession or city'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  key: const Key('mode_suggestions'),
                  label: Text(tr('Suggestions')),
                  selected: !_nearby,
                  onSelected: (_) => _setNearby(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('mode_nearby'),
                  label: Text(tr('Nearby')),
                  selected: _nearby,
                  onSelected: (_) => _setNearby(true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _body()),
          if (_loading && _results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(color: AppTheme.green),
            ),
        ],
      ),
    );
  }
}

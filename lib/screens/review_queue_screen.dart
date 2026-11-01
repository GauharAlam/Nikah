import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backend.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';
import '../widgets/load_states.dart';

/// Reviewer tool: decide on submitted profiles and documents. The route needs
/// the `reviewer` claim, and every action is re-checked on the server.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  List<Map<String, dynamic>>? _items;
  List<ReportItem>? _reports;
  String? _error;
  bool _busy = false;

  /// Photos the reviewer marked for replacement, by member.
  final Map<String, Set<String>> _flagged = <String, Set<String>>{};

  Backend get _backend => context.read<AppStore>().backend!;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> items = await _backend.listReviewQueue();
      final List<ReportItem> reports = await _backend.listReports();
      if (mounted) {
        setState(() {
          _items = items;
          _reports = reports;
          _error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<String?> _askReason(String title) {
    final TextEditingController reason = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('review_reason'),
          controller: reason,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Shown to the member'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('review_reason_send'),
            onPressed: () => Navigator.of(ctx).pop(reason.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(reason.dispose);
  }

  Future<void> _act(Future<void> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
      await _load();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> item, String decision) async {
    final String uid = item['uid'] as String;
    final String title = decision == 'changes' ? 'What should they change?' : 'Why is this rejected?';
    final String? reason = decision == 'approve' ? '' : await _askReason(title);
    if (reason == null || (decision != 'approve' && reason.isEmpty)) return;
    await _act(() => _backend.reviewProfile(
          uid,
          decision: decision,
          version: (item['version'] as num).toInt(),
          reason: reason,
          rejectedPhotos: (_flagged[uid] ?? const <String>{}).toList(),
        ));
  }

  Future<void> _decideDocument(String uid, String type, String decision) async {
    final String? reason = decision == 'approve' ? '' : await _askReason('What is wrong with it?');
    if (reason == null || (decision != 'approve' && reason.isEmpty)) return;
    await _act(() => _backend.reviewDocument(uid, type, decision: decision, reason: reason));
  }

  Future<void> _open(String uid, String type) async {
    try {
      for (final String url in await _backend.documentUrls(uid, type)) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      }
      await _load();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  Widget _row(String label, Object? value) {
    final String text = value is List ? value.join(', ') : '${value ?? ''}';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text('$label: $text', style: AppTheme.bodySmall),
    );
  }

  Widget _photos(String uid, List<dynamic> photos) {
    final Set<String> flagged = _flagged[uid] ?? <String>{};
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final Map<dynamic, dynamic> raw in photos.cast<Map<dynamic, dynamic>>())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  final String path = raw['path'] as String;
                  _flagged[uid] = flagged.contains(path)
                      ? (flagged..remove(path))
                      : (flagged..add(path));
                }),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: flagged.contains(raw['path'])
                          ? AppTheme.danger
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Image.network(
                    raw['url'] as String,
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 86,
                      height: 86,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final String uid = item['uid'] as String;
    final Map<dynamic, dynamic> d = item['draft'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{};
    final List<dynamic> docs = item['documents'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> photos = item['photos'] as List<dynamic>? ?? const <dynamic>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${d['fullName'] ?? ''}${item['isEdit'] == true ? ' (edit)' : ''}',
              style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
            ),
            _row('Managed by', d['managedBy']),
            _row('Status', d['maritalStatus']),
            _row('Readiness', d['marriageReadiness']),
            _row('Home', d['homeCity']),
            _row('Education', d['qualification']),
            _row('Alma mater', d['almaMaters']),
            _row('Profession', d['profession']),
            _row('Family', d['familyBackground']),
            _row('About', d['aboutMe']),
            const SizedBox(height: 8),
            if (photos.isNotEmpty) _photos(uid, photos),
            if (photos.isNotEmpty)
              Text('Tap a photo to ask for a replacement.', style: AppTheme.bodySmall),
            for (final dynamic raw in docs) _documentRow(uid, raw as Map<dynamic, dynamic>),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  key: Key('reject_$uid'),
                  onPressed: _busy ? null : () => _decide(item, 'reject'),
                  child: const Text('Reject'),
                ),
                TextButton(
                  key: Key('changes_$uid'),
                  onPressed: _busy ? null : () => _decide(item, 'changes'),
                  child: const Text('Ask for changes'),
                ),
                FilledButton(
                  key: Key('approve_$uid'),
                  onPressed: _busy ? null : () => _decide(item, 'approve'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentRow(String uid, Map<dynamic, dynamic> doc) {
    final String type = doc['type'] as String;
    final bool waiting = doc['status'] == 'pending' || doc['status'] == 'under_review';
    return Row(
      children: <Widget>[
        Expanded(child: Text('$type (${doc['status']})')),
        IconButton(
          tooltip: 'View document',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => _open(uid, type),
        ),
        if (waiting) ...<Widget>[
          IconButton(
            tooltip: 'Approve document',
            icon: const Icon(Icons.check_rounded),
            onPressed: _busy ? null : () => _decideDocument(uid, type, 'approve'),
          ),
          IconButton(
            tooltip: 'Ask for a new upload',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : () => _decideDocument(uid, type, 'resubmit'),
          ),
          IconButton(
            tooltip: 'Reject document',
            icon: const Icon(Icons.close_rounded),
            onPressed: _busy ? null : () => _decideDocument(uid, type, 'reject'),
          ),
        ],
      ],
    );
  }

  Widget _reportCard(ReportItem r) {
    return Card(
      key: Key('report_${r.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              r.name.isEmpty ? r.target : r.name,
              style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
            ),
            Text('${r.reason} (${r.context})'),
            if (r.details.isNotEmpty) Text(r.details, style: AppTheme.bodySmall),
            Text('${r.count} open · ${r.held ? 'held' : 'live'}', style: AppTheme.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (r.held)
                  TextButton(
                    key: Key('release_${r.target}'),
                    onPressed: _busy ? null : () => _act(() => _backend.releaseHold(r.target)),
                    child: const Text('Release hold'),
                  ),
                TextButton(
                  key: Key('dismiss_${r.id}'),
                  onPressed: _busy ? null : () => _act(() => _backend.resolveReport(r.id, decision: 'dismiss')),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  key: Key('uphold_${r.id}'),
                  onPressed: _busy ? null : () => _act(() => _backend.resolveReport(r.id, decision: 'uphold')),
                  child: const Text('Uphold'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Widget> cards, String empty) => cards.isEmpty
      ? EmptyState(icon: Icons.task_alt_rounded, title: 'Queue is empty', body: empty)
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(14), children: cards),
        );

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>>? items = _items;
    final List<ReportItem>? reports = _reports;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review queue'),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: 'Profiles (${items?.length ?? 0})'),
              Tab(key: const Key('reports_tab'), text: 'Reports (${reports?.length ?? 0})'),
            ],
          ),
        ),
        body: _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : items == null || reports == null
                ? const AppSkeleton()
                : TabBarView(
                    children: <Widget>[
                      _list(items.map(_card).toList(), 'No profiles are waiting for review.'),
                      _list(reports.map(_reportCard).toList(), 'No reports are open.'),
                    ],
                  ),
      ),
    );
  }
}

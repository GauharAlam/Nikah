import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backend.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

/// Reviewer tool: approve or reject submitted profiles and documents. The
/// route needs the `reviewer` claim, and every action is re-checked on the server.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  Backend get _backend => context.read<AppStore>().backend!;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> items = await _backend.listReviewQueue();
      if (mounted) setState(() => _items = items);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<String?> _askReason() {
    final TextEditingController reason = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Reason shown to the member'),
        content: TextField(controller: reason, maxLength: 300, maxLines: 3),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(reason.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    ).whenComplete(reason.dispose);
  }

  Future<void> _decide(String uid, {required bool approve}) async {
    final String? reason = approve ? '' : await _askReason();
    if (reason == null || (!approve && reason.isEmpty)) return;
    try {
      await _backend.reviewProfile(uid, approve: approve, reason: reason);
      await _load();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _decideDocument(String uid, String type, {required bool approve}) async {
    final String? reason = approve ? '' : await _askReason();
    if (reason == null || (!approve && reason.isEmpty)) return;
    try {
      await _backend.reviewDocument(uid, type, approve: approve, reason: reason);
      await _load();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _open(String uid, String type) async {
    try {
      for (final String url in await _backend.documentUrls(uid, type)) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      }
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  Widget _card(Map<String, dynamic> item) {
    final String uid = item['uid'] as String;
    final Map<dynamic, dynamic> d = item['draft'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{};
    final List<dynamic> docs = item['documents'] as List<dynamic>? ?? const <dynamic>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${d['fullName'] ?? ''}',
                style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900)),
            Text('${d['qualification'] ?? ''} · ${d['profession'] ?? ''}'),
            Text((d['almaMaters'] as List<dynamic>? ?? const <dynamic>[]).join(', ')),
            Text('${d['homeCity'] ?? ''} · ${(d['photos'] as List<dynamic>? ?? const <dynamic>[]).length} photos'),
            for (final dynamic raw in docs)
              Row(
                children: <Widget>[
                  Expanded(child: Text('${(raw as Map<dynamic, dynamic>)['type']} (${raw['status']})')),
                  IconButton(
                    tooltip: 'View document',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => _open(uid, raw['type'] as String),
                  ),
                  IconButton(
                    tooltip: 'Approve document',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => _decideDocument(uid, raw['type'] as String, approve: true),
                  ),
                  IconButton(
                    tooltip: 'Reject document',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _decideDocument(uid, raw['type'] as String, approve: false),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => _decide(uid, approve: false),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: () => _decide(uid, approve: true),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>>? items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Review queue')),
      body: _error != null
          ? Center(child: Text(_error!))
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Queue is empty',
                      body: 'No profiles are waiting for review.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: items.map(_card).toList(),
                      ),
                    ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';
import '../widgets/load_states.dart';

/// Explains what deleting does, then does it. An old session is asked to prove
/// it is the owner first.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final AppStore store = context.read<AppStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.deleteAccount();
      // The auth stream takes the app back to the landing page.
    } on BackendException catch (e) {
      if (e.kind == FailureKind.recentSignInNeeded && mounted) {
        await context.push(AppRoutes.verifyPhone);
        if (mounted) setState(() => _error = tr('Thank you. Tap Delete once more to finish.'));
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _point(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('•  $text', style: AppTheme.bodySmall),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Delete Account'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(tr('This cannot be undone'), style: AppTheme.ts(20, FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 14),
          Text(tr('We will delete'), style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 8),
          _point(tr('Your profile, photos and verification documents')),
          _point(tr('Your proposals, matches and conversations, for both sides')),
          _point(tr('Your family circle and anything shared with it')),
          _point(tr('Your notifications and device records')),
          const SizedBox(height: 10),
          Text(tr('We keep only'), style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 8),
          _point(tr('Payment records the law requires, without your name or number')),
          _point(tr('Reports other members made about you, for safety review')),
          const SizedBox(height: 6),
          Text(tr('To pause instead, use Pause my profile in Settings.'), style: AppTheme.bodySmall),
          CheckboxListTile(
            key: const Key('delete_agree'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('I understand my account will be permanently deleted.')),
            value: _agreed,
            onChanged: _busy ? null : (bool? v) => setState(() => _agreed = v ?? false),
          ),
          if (_error != null) ...<Widget>[
            Text(_error!, key: const Key('delete_error'), style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger)),
            const SizedBox(height: 10),
          ],
          DangerButton(
            key: const Key('delete_confirm'),
            label: _busy ? tr('Please wait…') : tr('Delete Account'),
            onPressed: () {
              if (_agreed && !_busy) unawaited(_delete());
            },
          ),
        ],
      ),
    );
  }
}

class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  List<BlockedMember>? _blocks;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final List<BlockedMember> blocks = await context.read<AppStore>().blockedMembers();
      if (mounted) {
        setState(() {
          _blocks = blocks;
          _error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(BlockedMember member) async {
    try {
      await context.read<AppStore>().unblockProfile(member.id);
      await _load();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BlockedMember>? blocks = _blocks;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Blocked members'))),
      body: _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : blocks == null
              ? const AppSkeleton()
              : blocks.isEmpty
                  ? EmptyState(
                      icon: Icons.block_rounded,
                      title: tr('Nobody is blocked'),
                      body: tr('People you block will appear here.'),
                    )
                  : ListView(
                      children: <Widget>[
                        for (final BlockedMember m in blocks)
                          ListTile(
                            key: Key('blocked_${m.id}'),
                            title: Text(m.name),
                            subtitle: Text(tr('A closed match stays closed.')),
                            trailing: TextButton(
                              onPressed: () => _unblock(m),
                              child: Text(tr('Unblock')),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

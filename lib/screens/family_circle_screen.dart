import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';
import '../widgets/empty_state.dart';

const Map<String, String> familyOpinionLabels = <String, String>{
  'good': 'Looks good',
  'discuss': 'Let us discuss',
  'no': 'Not suitable',
};

const Map<String, String> _historyLabels = <String, String>{
  'invited': 'Invitation sent',
  'resent': 'Invitation sent again',
  'cancelled': 'Invitation cancelled',
  'rejected': 'Invitation declined',
  'joined': 'Joined your circle',
  'permissions_changed': 'Access changed',
  'removed': 'Removed from your circle',
  'proposal_accepted': 'Accepted a proposal for you',
  'proposal_declined': 'Declined a proposal for you',
};

/// Permissions as tick boxes. Used when inviting and when changing access.
class _PermissionPicker extends StatelessWidget {
  const _PermissionPicker({required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final MapEntry<String, String> p in familyPermissionLabels.entries)
          CheckboxListTile(
            key: Key('perm_${p.key}'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(p.value)),
            value: selected.contains(p.key),
            onChanged: (bool? v) => onChanged(
              v == true ? <String>{...selected, p.key} : selected.difference(<String>{p.key}),
            ),
          ),
      ],
    );
  }
}

/// The owner's hub: who is in the circle, what each person can do, and the
/// record of every change. The owner can remove anyone at any time.
class FamilyCircleScreen extends StatelessWidget {
  const FamilyCircleScreen({super.key});

  Future<void> _share(String code) => SharePlus.instance.share(ShareParams(
        text: 'Please join my family circle on ${AppBrand.name}. Install the app, sign in '
            'with this phone number, and enter code $code within 7 days: ${AppConfig.appLink}',
      ));

  Future<void> _invite(BuildContext context, AppStore store) async {
    final bool? sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(store: store, share: _share),
    );
    if (sent == true && context.mounted) showSuccessSnack(context, tr('Invitation ready to share.'));
  }

  Future<void> _edit(BuildContext context, AppStore store, FamilyMember member) async {
    Set<String> chosen = member.permissions.toSet();
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter set) => AlertDialog(
          title: Text(member.name),
          content: SingleChildScrollView(
            child: _PermissionPicker(selected: chosen, onChanged: (Set<String> v) => set(() => chosen = v)),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Cancel'))),
            FilledButton(
              key: const Key('save_permissions'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Save')),
            ),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      await _run(context, () => store.updateGuardianPermissions(member.uid, chosen.toList()));
    }
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on BackendException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final FamilyState family = store.family;
    final FamilyAdmin admin = store.familyAdmin;
    final List<FamilyInvitation> pending =
        admin.invitations.where((FamilyInvitation i) => i.isPending).toList();
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Family Circle'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            tr('You decide what each family member can do. Nobody in your circle can see your chats, documents or number, or take over your account. You can remove anyone at any time.'),
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            key: const Key('invite_family'),
            label: tr('Invite family'),
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _invite(context, store),
          ),
          const SizedBox(height: 18),
          for (final FamilyMember m in admin.members)
            ListTile(
              key: Key('family_member_${m.uid}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text('${m.name} · ${tr(familyRelationships[m.relationship] ?? m.relationship)}'),
              subtitle: Text(m.permissions.isEmpty
                  ? tr('No access')
                  : m.permissions.map((String p) => tr(familyPermissionLabels[p] ?? p)).join(', ')),
              isThreeLine: true,
              onTap: () => _edit(context, store, m),
              trailing: TextButton(
                key: Key('remove_${m.uid}'),
                onPressed: () => _run(context, () => store.removeGuardian(m.uid)),
                child: Text(tr('Remove')),
              ),
            ),
          if (pending.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(tr('Waiting to join'), style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900)),
            for (final FamilyInvitation i in pending)
              ListTile(
                key: Key('invitation_${i.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(i.name),
                subtitle: Text(tr(familyRelationships[i.relationship] ?? i.relationship)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => _run(context, () async => _share(await store.resendFamilyInvite(i.id))),
                      child: Text(tr('Resend')),
                    ),
                    TextButton(
                      onPressed: () => _run(context, () => store.cancelFamilyInvite(i.id)),
                      child: Text(tr('Cancel')),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(tr('Shared with family'), style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 8),
          if (family.shortlist.isEmpty)
            EmptyState(
              icon: Icons.groups_outlined,
              title: tr('Nothing shared yet'),
              body: tr('Open a profile and tap the family icon to share it.'),
            ),
          for (final FamilyPick pick in family.shortlist)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(pick.title, style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
                    Text(pick.summary, style: AppTheme.bodySmall),
                    for (final MapEntry<String, String> o in pick.opinions.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${family.guardians[o.key] ?? tr('Family')}: ${tr(familyOpinionLabels[o.value] ?? '')}',
                          style: AppTheme.ts(12.5, FontWeight.w700, color: AppTheme.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (admin.history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ExpansionTile(
              key: const Key('family_history'),
              tilePadding: EdgeInsets.zero,
              title: Text(tr('Access history')),
              children: <Widget>[
                for (final FamilyEvent e in admin.history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr(_historyLabels[e.action] ?? e.action)),
                    subtitle: Text(AppStore.fmtDate(e.at)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.store, required this.share});

  final AppStore store;
  final Future<void> Function(String code) share;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  String _relationship = 'father';
  Set<String> _permissions = <String>{'view_shortlist'};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String code = await widget.store.createFamilyInvite(
        name: _name.text.trim(),
        relationship: _relationship,
        phone: _phone.text.trim(),
        permissions: _permissions.toList(),
      );
      await widget.share(code);
      if (mounted) Navigator.of(context).pop(true);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(tr('Invite family'), style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('invite_name'),
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(hintText: tr('Their name'), counterText: ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const Key('invite_relationship'),
                initialValue: _relationship,
                items: <DropdownMenuItem<String>>[
                  for (final MapEntry<String, String> r in familyRelationships.entries)
                    DropdownMenuItem<String>(value: r.key, child: Text(tr(r.value))),
                ],
                onChanged: (String? v) => setState(() => _relationship = v ?? _relationship),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('invite_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: tr('Their phone number, with country code')),
              ),
              const SizedBox(height: 6),
              Text(tr('Only this number can use the invitation.'), style: AppTheme.bodySmall),
              const SizedBox(height: 10),
              Text(tr('They can'), style: AppTheme.ts(14, FontWeight.w800, color: AppTheme.slate900)),
              _PermissionPicker(
                selected: _permissions,
                onChanged: (Set<String> v) => setState(() => _permissions = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger)),
                ),
              PrimaryButton(
                key: const Key('invite_send'),
                label: tr('Create invitation'),
                progress: _busy,
                onPressed: _busy ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The family member's side, and the person a family-made profile is about.
class FamilyViewScreen extends StatefulWidget {
  const FamilyViewScreen({super.key});

  @override
  State<FamilyViewScreen> createState() => _FamilyViewScreenState();
}

class _FamilyViewScreenState extends State<FamilyViewScreen> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;
  FamilyOverview? _overview;
  String? _loadedFor;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _loadOverview(AppStore store) {
    final String key = store.guardianView == null ? '' : store.uid;
    if (key.isEmpty || _loadedFor == key) return;
    _loadedFor = key;
    unawaited(() async {
      try {
        final FamilyOverview? o = await store.familyOverview();
        if (mounted) setState(() => _overview = o);
      } on BackendException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    }());
  }

  Widget _codeForm(AppStore store) {
    final String code = _code.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(tr('Enter the code you were sent. Sign in with the number it was sent to.'), style: AppTheme.bodySmall),
        const SizedBox(height: 14),
        TextField(
          key: const Key('family_code'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('Family code'), counterText: ''),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          key: const Key('join_family'),
          label: tr('Join family circle'),
          progress: _busy,
          onPressed: _busy || code.length != 6 ? null : () => _run(() => store.joinFamily(code)),
        ),
        TextButton(
          key: const Key('reject_family'),
          onPressed: _busy || code.length != 6 ? null : () => _run(() => store.rejectFamilyInvite(code)),
          child: Text(tr('Decline this invitation')),
        ),
        const Divider(height: 28),
        Text(tr('Someone made a profile for you?'), style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 6),
        Text(tr('Enter their code to say whether you agree. It will not go live without your yes.'), style: AppTheme.bodySmall),
        Row(
          children: <Widget>[
            Expanded(
              child: TextButton(
                key: const Key('subject_agree'),
                onPressed: _busy || code.length != 6
                    ? null
                    : () => _run(() => store.confirmSubject(code, agree: true)),
                child: Text(tr('I agree')),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const Key('subject_refuse'),
                onPressed: _busy || code.length != 6
                    ? null
                    : () => _run(() => store.confirmSubject(code, agree: false)),
                child: Text(tr('I do not agree')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _circle(AppStore store, FamilyState family) {
    final FamilyOverview? o = _overview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (o?.profileSummary != null) ...<Widget>[
          Text(tr('Their profile'), style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
          Text(o!.profileSummary!, key: const Key('family_profile'), style: AppTheme.bodySmall),
          const SizedBox(height: 14),
        ],
        if (o?.proposals != null) ...<Widget>[
          Text(tr('Proposals received'), style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
          if (o!.proposals!.isEmpty) Text(tr('Nothing is waiting.'), style: AppTheme.bodySmall),
          for (final FamilyProposal p in o.proposals!)
            ListTile(
              key: Key('family_proposal_${p.from}'),
              contentPadding: EdgeInsets.zero,
              title: Text(p.summary),
              trailing: o.permissions.contains('manage_proposals')
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: tr('Decline'),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => _answer(store, p.from, false),
                        ),
                        IconButton(
                          tooltip: tr('Accept'),
                          icon: const Icon(Icons.check_rounded),
                          onPressed: () => _answer(store, p.from, true),
                        ),
                      ],
                    )
                  : null,
            ),
          const SizedBox(height: 14),
        ],
        if (family.shortlist.isEmpty)
          EmptyState(
            icon: Icons.groups_outlined,
            title: tr('Nothing shared yet'),
            body: tr('Profiles your family member shares will appear here.'),
          ),
        for (final FamilyPick pick in family.shortlist)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(pick.title, style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.slate900)),
                  Text(pick.summary, style: AppTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final MapEntry<String, String> op in familyOpinionLabels.entries)
                        ChoiceChip(
                          label: Text(tr(op.value)),
                          selected: pick.opinions[store.uid] == op.key,
                          onSelected: (_) => store.giveFamilyOpinion(pick.id, op.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          key: const Key('leave_family'),
          onPressed: () => _run(store.leaveFamily),
          child: Text(tr('Leave this family circle')),
        ),
      ],
    );
  }

  Future<void> _answer(AppStore store, String from, bool accept) => _run(() async {
        await store.answerForMember(from, accept: accept);
        _loadedFor = null;
        _overview = null;
      });

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final FamilyState? family = store.guardianView;
    _loadOverview(store);
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Family Circle'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          if (family == null) _codeForm(store) else _circle(store, family),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_error!, style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger)),
          ],
          if (store.isSubjectOfProfile) ...<Widget>[
            const Divider(height: 28),
            Text(tr('You confirmed a profile made for you.'), style: AppTheme.bodySmall),
            TextButton(
              key: const Key('subject_withdraw'),
              onPressed: _busy ? null : () => _run(store.withdrawSubject),
              child: Text(tr('Withdraw my agreement and take it down')),
            ),
          ],
          TextButton(onPressed: store.signOut, child: Text(tr('Log out'))),
        ],
      ),
    );
  }
}

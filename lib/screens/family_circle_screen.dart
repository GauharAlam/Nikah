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

/// The member's side: who is in the circle, and what they think.
class FamilyCircleScreen extends StatelessWidget {
  const FamilyCircleScreen({super.key});

  Future<void> _invite(BuildContext context, AppStore store) async {
    try {
      final String code = await store.createFamilyInvite();
      await SharePlus.instance.share(ShareParams(
        text: 'Please join my family circle on ${AppBrand.name}. '
            'Install the app and enter code $code within 7 days: ${AppConfig.appLink}',
      ));
    } on BackendException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final FamilyState family = store.family;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Family Circle'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            tr('Family can see only the profiles you share, without photos or numbers. They cannot see your chats or documents.'),
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
          for (final MapEntry<String, String> g in family.guardians.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(g.value),
              trailing: TextButton(
                onPressed: () => unawaited(store.removeGuardian(g.key)),
                child: Text(tr('Remove')),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            tr('Shared with family'),
            style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
          ),
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
        ],
      ),
    );
  }
}

/// The guardian's side: enter a code, then give an opinion on shared profiles.
class FamilyViewScreen extends StatefulWidget {
  const FamilyViewScreen({super.key});

  @override
  State<FamilyViewScreen> createState() => _FamilyViewScreenState();
}

class _FamilyViewScreenState extends State<FamilyViewScreen> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join(AppStore store) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.joinFamily(_code.text.trim(), _name.text.trim());
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final FamilyState? family = store.guardianView;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Family Circle'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          if (family == null) ...<Widget>[
            Text(tr('Enter the code your family member sent you.'), style: AppTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              key: const Key('family_code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(hintText: tr('Family code'), counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('family_name'),
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(hintText: tr('Your name'), counterText: ''),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              key: const Key('join_family'),
              label: tr('Join'),
              progress: _busy,
              onPressed: _busy ? null : () => _join(store),
            ),
          ] else ...<Widget>[
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
                          for (final MapEntry<String, String> o in familyOpinionLabels.entries)
                            ChoiceChip(
                              label: Text(tr(o.value)),
                              selected: pick.opinions[store.uid] == o.key,
                              onSelected: (_) => store.giveFamilyOpinion(pick.id, o.key),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          TextButton(onPressed: store.signOut, child: Text(tr('Log out'))),
        ],
      ),
    );
  }
}

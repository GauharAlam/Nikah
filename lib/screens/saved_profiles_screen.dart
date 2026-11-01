import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../l10n/app_strings.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/empty_state.dart';
import '../widgets/load_states.dart';

/// Profiles this member saved. The list is private to them.
class SavedProfilesScreen extends StatefulWidget {
  const SavedProfilesScreen({super.key});

  @override
  State<SavedProfilesScreen> createState() => _SavedProfilesScreenState();
}

class _SavedProfilesScreenState extends State<SavedProfilesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<AppStore>().loadBookmarks());
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<MatchProfile> saved = store.bookmarkedProfiles;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Saved profiles'))),
      body: saved.isEmpty && store.isLoadingBookmarks
          ? const AppSkeleton()
          : saved.isEmpty
          ? EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Nothing saved yet',
              body: 'Tap the bookmark on a profile to keep it here. Only you can see this list.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final MatchProfile p = saved[index];
                return AppCard(
                  key: Key('saved_${p.id}'),
                  padding: const EdgeInsets.all(12),
                  onTap: () => context.push(AppRoutes.matchDetail(p.id)),
                  child: Row(
                    children: <Widget>[
                      ClipOval(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: AppNetworkImage(url: p.imageUrl),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${p.firstName}, ${p.age}',
                              style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              p.profession,
                              style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_images.dart';
import '../widgets/how_to_use_sheet.dart';

/// First screen after approval: the member's live card and a short pledge.
class ApprovedScreen extends StatefulWidget {
  const ApprovedScreen({super.key});

  @override
  State<ApprovedScreen> createState() => _ApprovedScreenState();
}

class _ApprovedScreenState extends State<ApprovedScreen> {
  String _photo = '';

  @override
  void initState() {
    super.initState();
    final AppStore store = context.read<AppStore>();
    final List<String> photos = store.profile?.photos ?? const <String>[];
    if (photos.isNotEmpty) unawaited(_loadPhoto(store, photos.first));
  }

  Future<void> _loadPhoto(AppStore store, String stored) async {
    try {
      final String url = await store.photoSource(stored);
      if (mounted && url.startsWith('http')) setState(() => _photo = url);
    } on BackendException {
      // The card still reads correctly with its placeholder.
    }
  }

  Future<void> _start(AppStore store) async {
    await showHowToUseSheet(context, store);
    if (mounted) store.acceptPledge();
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final WardProfile? p = store.profile;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              const Icon(Icons.star_rounded, size: 56, color: AppTheme.goldAccent),
              const SizedBox(height: 8),
              Text(
                tr('Your profile is approved!'),
                style: AppTheme.ts(24, FontWeight.w800, color: AppTheme.slate900),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      AppNetworkImage(url: _photo),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: double.infinity,
                          color: AppTheme.ink.withValues(alpha: 0.82),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${p?.displayName ?? ''}, ${p?.age ?? ''}',
                                style: AppTheme.ts(20, FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                <String>[p?.profession ?? '', p?.city ?? '']
                                    .where((String s) => s.isNotEmpty)
                                    .join(' · '),
                                style: AppTheme.ts(13, FontWeight.w600, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'I promise to use ${AppBrand.name} with pure intentions by '
                'maintaining community\'s dignity.',
                textAlign: TextAlign.center,
                style: AppTheme.ts(15, FontWeight.w500, color: AppTheme.slate700, height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  key: const Key('start_bismillah'),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.goldAccent),
                  label: Text(tr('Start with Bismillah')),
                  onPressed: () => _start(store),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

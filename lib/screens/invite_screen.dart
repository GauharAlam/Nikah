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

/// A member's invite code and what it has earned.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  InviteInfo? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final InviteInfo info = await context.read<AppStore>().inviteInfo();
      if (mounted) setState(() => _info = info);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _share(InviteInfo info) {
    unawaited(SharePlus.instance.share(ShareParams(
      text: 'Assalamu alaikum. I am using ${AppBrand.name} for nikah. '
          'Use my code ${info.code} when you join: ${AppConfig.appLink}',
    )));
  }

  @override
  Widget build(BuildContext context) {
    final InviteInfo? info = _info;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Invite and earn'))),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: _error != null
            ? Center(child: Text(_error!))
            : info == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        tr('Earn contact credits when someone you invite is approved.'),
                        style: AppTheme.ts(16, FontWeight.w600, color: AppTheme.slate800, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SelectableText(
                        info.code,
                        key: const Key('invite_code'),
                        textAlign: TextAlign.center,
                        style: AppTheme.ts(34, FontWeight.w800, color: AppTheme.green, letterSpacing: 4),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        key: const Key('share_invite'),
                        label: tr('Share invite'),
                        icon: Icons.share_rounded,
                        onPressed: () => _share(info),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${info.invited} ${tr('approved')}  ·  ${info.earned} ${tr('credits earned')}',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall,
                      ),
                      if (AppConfig.isDemo) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          tr('Demo build: this code earns nothing.'),
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

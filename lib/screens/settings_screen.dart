import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_switch.dart';

/// Settings & privacy hub: notifications, modesty toggles, guardian
/// surfaces and account data controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 60),
        children: <Widget>[
          const SectionLabel('Notifications'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: <Widget>[
                SwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push notifications',
                  subtitle: 'New matches, intros & milestones',
                  value: store.pushEnabled,
                  onChanged: store.setPushEnabled,
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email digest',
                  subtitle: 'A calm weekly summary of activity',
                  value: store.emailDigest,
                  onChanged: store.setEmailDigest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Privacy & modesty'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: <Widget>[
                SwitchTile(
                  icon: Icons.translate_rounded,
                  title: 'Show Arabic lines',
                  subtitle: 'Display original Arabic verses & du\'a',
                  value: store.showArabic,
                  onChanged: store.setShowArabic,
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.blur_on_rounded,
                  title: 'Modesty blur on photos',
                  subtitle: 'Soft blur until mutual approval',
                  value: store.privacy('blurPhotos'),
                  onChanged: (bool v) => store.togglePrivacy('blurPhotos', v),
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts for matches',
                  subtitle: 'Let your Wali track thread attendance',
                  value: store.privacy('readReceipts'),
                  onChanged: (bool v) => store.togglePrivacy('readReceipts', v),
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide me from non-verified members',
                  subtitle: 'Only Wali-verified accounts can view you',
                  value: store.privacy('hideFromNonVerified'),
                  onChanged: (bool v) =>
                      store.togglePrivacy('hideFromNonVerified', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Guardian'),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Wali & Guardian Hub',
            subtitle:
                '${store.guardian.name} · ${store.guardian.relation.label}',
            onTap: () => context.push(AppRoutes.waliHub),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.sms_outlined,
            title: 'Wali Verification Portal',
            subtitle: '6-digit guardian passcode',
            onTap: () => context.push(AppRoutes.waliPortal),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Account'),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.edit_outlined,
            title: 'Edit Biodata',
            subtitle: 'Update your visible profile',
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About Barkat Nikah',
            subtitle: 'FAQs, guidelines & support',
            onTap: () => context.push(AppRoutes.about),
          ),
          const SizedBox(height: 26),
          DangerButton(
            label: 'Reset App Data',
            onPressed: () => _confirmReset(context, store),
          ),
          const SizedBox(height: 26),
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mosque,
                      size: 20, color: AppTheme.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Barkat Nikah · v1.0.0+1',
                  style: AppTheme.ts(11.5, FontWeight.w600,
                      color: AppTheme.slate400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmReset(
      BuildContext context, AppStore store) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
          'This clears your biodata, chats, guardian settings and '
          'notifications from this device. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep my data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.resetAll();
    if (context.mounted) context.go(AppRoutes.landing);
  }
}

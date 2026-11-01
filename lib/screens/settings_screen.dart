import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../app_router.dart';
import '../config/app_config.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_switch.dart';
import '../widgets/picker_sheets.dart';

/// Settings & privacy hub: notifications, modesty toggles, guardian
/// surfaces and account data controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Settings & Privacy'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 60),
        children: <Widget>[
          if (AppConfig.isDemo) ...<Widget>[
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
          ],
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
                  key: const Key('photos_after_match_setting'),
                  icon: Icons.visibility_off_outlined,
                  title: tr('Show my photos only after we match'),
                  subtitle: tr('Others see your details, but not your face'),
                  value: store.profile?.photoPrivacy == 'matches',
                  onChanged: (bool v) =>
                      store.updatePrivacy(photoPrivacy: v ? 'matches' : 'everyone'),
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.groups_outlined,
                  title: tr('Show my caste'),
                  subtitle: tr('Turn off to keep it private'),
                  value: store.profile?.showCaste ?? true,
                  onChanged: (bool v) => store.updatePrivacy(showCaste: v),
                ),
                const Divider(height: 20),
                SwitchTile(
                  icon: Icons.share_outlined,
                  title: tr('Allow sharing with families'),
                  subtitle: tr('A summary with no photo or number'),
                  value: store.profile?.allowFamilyShare ?? true,
                  onChanged: (bool v) => store.updatePrivacy(allowFamilyShare: v),
                ),
                if (AppConfig.isDemo) const Divider(height: 20),
                if (AppConfig.isDemo) SwitchTile(
                  icon: Icons.blur_on_rounded,
                  title: 'Modesty blur on photos',
                  subtitle: 'Soft blur until mutual approval',
                  value: store.privacy('blurPhotos'),
                  onChanged: (bool v) => store.togglePrivacy('blurPhotos', v),
                ),
                if (AppConfig.isDemo) const Divider(height: 20),
                if (AppConfig.isDemo) SwitchTile(
                  icon: Icons.done_all_rounded,
                  title: 'Read receipts for matches',
                  subtitle: 'Show when you have read a message',
                  value: store.privacy('readReceipts'),
                  onChanged: (bool v) => store.togglePrivacy('readReceipts', v),
                ),
              ],
            ),
          ),
          if (AppConfig.guardianFeatures) ...<Widget>[
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
          ],
          const SizedBox(height: 22),
          const SectionLabel('Account'),
          const SizedBox(height: 10),
          SettingsTile(
            key: const Key('settings_language'),
            icon: Icons.translate_rounded,
            title: tr('Language'),
            subtitle: store.language.label,
            onTap: () => pickLanguage(context),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.shield_outlined,
            title: tr('Safety Centre'),
            subtitle: tr('Scams to watch for and how to report'),
            onTap: () => context.push(AppRoutes.safety),
          ),
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
            label: tr('Delete Account'),
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
        title: const Text('Delete your account?'),
        content: const Text(
          'Your profile, proposals and chats will be '
          'permanently deleted. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep my data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.resetAll();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../app_router.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../services/app_lock.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';
import '../widgets/app_switch.dart';
import '../widgets/picker_sheets.dart';

/// Settings & privacy hub: notifications, modesty toggles, guardian
/// surfaces and account data controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pause(BuildContext context, AppStore store, bool paused) async {
    try {
      await store.setPaused(paused);
    } on BackendException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _setLock(BuildContext context, AppStore store, bool on) async {
    final bool done = await AppLock.setEnabled(store.prefs, on);
    if (context.mounted && !done) {
      showAppSnack(context, tr('This phone has no screen lock set up.'));
    }
    store.settingsChanged();
  }

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
                  key: const Key('pause_setting'),
                  icon: Icons.pause_circle_outline_rounded,
                  title: tr('Pause my profile'),
                  subtitle: tr('Hide me from everyone, and keep everything'),
                  value: store.isPaused,
                  onChanged: (bool v) => unawaited(_pause(context, store, v)),
                ),
                const Divider(height: 20),
                SwitchTile(
                  key: const Key('contact_requests_setting'),
                  icon: Icons.contact_phone_outlined,
                  title: tr('Allow contact requests'),
                  subtitle: tr('Your number is only shared if you accept'),
                  value: store.profile?.allowContactRequests ?? true,
                  onChanged: (bool v) => store.updatePrivacy(allowContactRequests: v),
                ),
                const Divider(height: 20),
                SwitchTile(
                  key: const Key('app_lock_setting'),
                  icon: Icons.lock_outline_rounded,
                  title: tr('App lock'),
                  subtitle: tr('Ask for your fingerprint, face or passcode'),
                  value: AppLock.enabled(store.prefs),
                  onChanged: (bool v) => unawaited(_setLock(context, store, v)),
                ),
                const Divider(height: 20),
                SwitchTile(
                  key: const Key('nearby_setting'),
                  icon: Icons.near_me_outlined,
                  title: tr('Nearby discovery'),
                  subtitle: tr('People who turn this on can find you by home city. Never GPS.'),
                  value: store.profile?.nearbyOptIn ?? false,
                  onChanged: (bool v) => store.updatePrivacy(nearbyOptIn: v),
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
          SettingsTile(
            key: const Key('blocked_members'),
            icon: Icons.block_rounded,
            title: tr('Blocked members'),
            subtitle: tr('See and unblock'),
            onTap: () => context.push(AppRoutes.blockedMembers),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            key: const Key('export_data'),
            icon: Icons.download_outlined,
            title: tr('Download my data'),
            subtitle: tr('A copy of what we hold about you'),
            onTap: () => _export(context, store),
          ),
          const SizedBox(height: 22),
          DangerButton(
            label: tr('Delete Account'),
            onPressed: () => context.push(AppRoutes.deleteAccount),
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

  static Future<void> _export(BuildContext context, AppStore store) async {
    try {
      final String json = await store.exportData();
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/my-nikah-data.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(file.path)]));
    } on BackendException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    }
  }
}

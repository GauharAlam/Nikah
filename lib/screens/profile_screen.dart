import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/ward_profile.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';

/// Bottom-nav Profile tab — the ward's own biodata hub with quick
/// actions to edit, guardian surfaces and account controls.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final WardProfile profile = store.profile ?? WardProfile.demoWard;
    final String name =
        profile.displayName.isEmpty ? 'Amina Al-Mansoor' : profile.displayName;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _ProfileHeader(
            name: name,
            city: profile.city.isEmpty ? 'Set your city' : profile.city,
            age: profile.age,
            verified: profile.waliVerified,
            initials: _initials(name),
            unread: store.unreadNotificationCount,
            onSettings: () => context.push(AppRoutes.settings),
            onNotifications: () => context.push(AppRoutes.notifications),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.edit_outlined,
                        title: 'Edit Biodata',
                        subtitle: 'Keep your record fresh',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.tune_rounded,
                        title: 'Preferences',
                        subtitle: 'Privacy & settings',
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.shield_outlined,
                        title: 'Wali Hub',
                        subtitle: store.guardian.isVerified
                            ? 'Verified guardian'
                            : 'Verification pending',
                        onTap: () => context.push(AppRoutes.waliHub),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.info_outline_rounded,
                        title: 'About & Help',
                        subtitle: 'FAQs and guidelines',
                        onTap: () => context.push(AppRoutes.about),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel('Biodata'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: <Widget>[
                    InfoTile(
                      label: 'City',
                      value: profile.city.isEmpty ? '—' : profile.city,
                    ),
                    InfoTile(
                      label: 'Country',
                      value: profile.country.isEmpty ? '—' : profile.country,
                    ),
                    InfoTile(
                      label: 'Education',
                      value: profile.education.isEmpty
                          ? '—'
                          : profile.education,
                    ),
                    InfoTile(
                      label: 'Profession',
                      value: profile.profession.isEmpty
                          ? '—'
                          : profile.profession,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel('Deen snapshot'),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _DeenRow(
                          label: 'Prayer',
                          value: profile.prayerFrequency.label),
                      _DeenRow(
                          label: 'Qur\'an comfort',
                          value: profile.quranComfort.label),
                      _DeenRow(label: 'Timeline', value: profile.timeline),
                      _DeenRow(label: 'Relocation', value: profile.relocation),
                      if (profile.halalLifestyle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: profile.halalLifestyle
                              .map<Widget>((String c) => TagChip(c))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Guardian oversight'),
                const SizedBox(height: 10),
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldDeep,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_user_outlined,
                            size: 20, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              store.guardian.name,
                              style: AppTheme.ts(14, FontWeight.w800,
                                  color: AppTheme.slate900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${store.guardian.relation.label} · '
                              '${store.guardian.phoneCode} '
                              '${store.guardian.phone}',
                              style: AppTheme.ts(12, FontWeight.w500,
                                  color: AppTheme.slate500),
                            ),
                          ],
                        ),
                      ),
                      store.guardian.isVerified
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.successBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.success
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    size: 12,
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: AppTheme.ts(10.5, FontWeight.w700,
                                        color: AppTheme.success),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warningBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Pending',
                                style: AppTheme.ts(10.5, FontWeight.w700,
                                    color: AppTheme.warning),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: store.unreadNotificationCount > 0
                      ? '${store.unreadNotificationCount} unread updates'
                      : 'All caught up, alhamdulillah',
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const SizedBox(height: 10),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy & modesty',
                  subtitle: store.privacy('blurPhotos')
                      ? 'Photo blur is ON'
                      : 'Photo blur is OFF',
                  onTap: () => context.push(AppRoutes.settings),
                ),
                const SizedBox(height: 22),
                if (store.isLoggedIn) ...<Widget>[
                  const SectionLabel('Account'),
                  const SizedBox(height: 10),
                  DangerButton(
                    label: 'Sign out',
                    onPressed: () => _confirmSignOut(context, store),
                  ),
                ] else ...<Widget>[
                  const InfoBanner(
                    icon: Icons.info_outline_rounded,
                    text: 'You are browsing as a guest. Create an account to '
                        'keep your biodata and chats saved.',
                    variant: InfoVariant.info,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Create account',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () {
                      store.enterOnboarding();
                      context.push(AppRoutes.signIn);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    return parts.take(2).map((String p) => p[0]).join().toUpperCase();
  }

  static Future<void> _confirmSignOut(
      BuildContext context, AppStore store) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your biodata, chats and guardian settings stay saved on this '
          'device, ready when you return.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    store.signOut();
    if (context.mounted) context.go(AppRoutes.signIn);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.city,
    required this.age,
    required this.verified,
    required this.initials,
    required this.unread,
    required this.onSettings,
    required this.onNotifications,
  });

  final String name;
  final String city;
  final int? age;
  final bool verified;
  final String initials;
  final int unread;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 26,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandWash,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Spacer(),
              NotificationBell(unread: unread, onTap: onNotifications),
              IconButton(
                tooltip: 'Settings',
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 23),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.7), width: 2),
            ),
            child: AppAvatar(url: '', initials: initials, radius: 42),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: AppTheme.ts(20, FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              city,
              if (age != null) '$age years',
            ].join(' · '),
            style: AppTheme.ts(13, FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 14),
          verified
              ? const VerifiedBadge()
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'Awaiting Wali verification',
                    style: AppTheme.ts(11, FontWeight.w700,
                        color: AppTheme.gold),
                  ),
                ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.emeraldDeep,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.gold),
          ),
          const SizedBox(height: 10),
          Text(title,
              style:
                  AppTheme.ts(13.5, FontWeight.w800, color: AppTheme.slate900)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style:
                AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DeenRow extends StatelessWidget {
  const _DeenRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTheme.ts(12.5, FontWeight.w600,
                  color: AppTheme.slate500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.ts(13, FontWeight.w700,
                  color: AppTheme.slate900),
            ),
          ),
        ],
      ),
    );
  }
}

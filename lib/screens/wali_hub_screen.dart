// Guardian dashboard — Wali identity header, privacy & modesty switches,
// guardian permission summary and the guardian audit log.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';
import '../widgets/app_switch.dart';
import '../widgets/empty_state.dart';

class WaliHubScreen extends StatelessWidget {
  const WaliHubScreen({super.key});

  static const List<(String, String)> _privacyControls = <(String, String)>[
    ('blurPhotos', 'Photos stay blurred until a match passes Wali review.'),
    ('readReceipts', 'Matched members see when you read their messages.'),
    ('activityAlerts', 'Notify your Wali of approvals, invites and messages.'),
    ('chatChaperone', 'Every supervised chat stays open to guardian audit.'),
    ('hideFromNonVerified', 'Stay invisible to members without a verified Wali.'),
  ];

  void _togglePrivacy(BuildContext context, String key, bool enabled) {
    context.read<AppStore>().togglePrivacy(key, enabled);
    showWaliSnack(
      context,
      '${AppStore.privacyLabel(key)} ${enabled ? 'enabled' : 'disabled'}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final Guardian guardian = store.guardian;
    final List<ActivityLogEntry> recentLog = store.activityLog.take(6).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Wali & Privacy Hub')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          _GuardianHeader(guardian: guardian),
          const SizedBox(height: 14),
          const InfoBanner(
            icon: Icons.menu_book_outlined,
            text: 'Your guardian reviews every step, per Quran 4:34. '
                'Transparency builds trust.',
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickAction(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Update Wali',
                  onTap: () => context.push(AppRoutes.waliOnboarding),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.sms_outlined,
                  title: 'Open SMS Portal',
                  onTap: () => context.push(AppRoutes.waliPortal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Privacy & Modesty',
            subtitle: 'Guardian-supervised defaults for dignified browsing.',
          ),
          const SizedBox(height: 12),
          ..._privacyControls.map(
            ((String, String) control) => AppSwitchRow(
              title: AppStore.privacyLabel(control.$1),
              subtitle: control.$2,
              value: store.privacy(control.$1),
              onChanged: (bool value) =>
                  _togglePrivacy(context, control.$1, value),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Guardian permissions',
            subtitle: 'Read-only mirror of what your Wali currently controls.',
          ),
          const SizedBox(height: 12),
          _PermissionRow(
            granted: guardian.allowIntroApprovals,
            title: 'Intro approvals',
            subtitle: 'Screens every Ta\'aruf request before chats open.',
          ),
          _PermissionRow(
            granted: guardian.allowChatAudit,
            title: 'Chat audit access',
            subtitle: 'Reviews supervised conversations for adab and safety.',
          ),
          _PermissionRow(
            granted: guardian.allowMeetingApproval,
            title: 'Meeting approvals',
            subtitle: 'Signs off each family meeting plan and venue.',
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Audit log',
            subtitle: 'Last 6 guardian-supervised events on this account.',
          ),
          const SizedBox(height: 12),
          if (recentLog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No guardian activity yet',
                body: 'Approvals, verifications and supervised events will '
                    'appear here as they happen.',
              ),
            )
          else
            ...recentLog.map(
              (ActivityLogEntry entry) => _AuditRow(entry: entry),
            ),
        ],
      ),
    );
  }
}

/// Dark emerald hero header with gold accents showing the appointed Wali.
class _GuardianHeader extends StatelessWidget {
  const _GuardianHeader({required this.guardian});

  final Guardian guardian;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandWash,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.emeraldDeep.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  guardian.name,
                  style: AppTheme.ts(17, FontWeight.w800, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  guardian.relation.label,
                  style: AppTheme.ts(12, FontWeight.w700, color: AppTheme.gold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (guardian.isVerified)
            const VerifiedBadge()
          else
            const _PendingPill(),
        ],
      ),
    );
  }
}

/// Warning pill shown when the guardian has not completed SMS verification.
class _PendingPill extends StatelessWidget {
  const _PendingPill();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(AppRoutes.waliPortal),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.warningBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
              const SizedBox(width: 5),
              Text(
                'Verification pending',
                style: AppTheme.ts(11, FontWeight.w700, color: AppTheme.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined mini action card used in the quick action row.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppTheme.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.ts(13, FontWeight.w700, color: AppTheme.slate800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only summary row of a guardian capability (check / cross icon).
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.granted,
    required this.title,
    required this.subtitle,
  });

  final bool granted;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.slate100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            granted ? Icons.check_circle : Icons.cancel_outlined,
            size: 20,
            color: granted ? AppTheme.success : AppTheme.slate400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            granted ? 'Granted' : 'Off',
            style: AppTheme.ts(
              11,
              FontWeight.w800,
              color: granted ? AppTheme.success : AppTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single entry of the guardian audit log with kind icon and relative time.
class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final ActivityLogEntry entry;

  static IconData _iconFor(ActivityKind kind) => switch (kind) {
        ActivityKind.verification => Icons.verified_user,
        ActivityKind.intro => Icons.handshake,
        ActivityKind.chat => Icons.forum,
        ActivityKind.meeting => Icons.event,
        ActivityKind.general => Icons.history,
      };

  static String _ageLabel(DateTime at) {
    final Duration diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(entry.kind), size: 18, color: AppTheme.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.detail,
                  style: AppTheme.ts(
                    12,
                    FontWeight.w500,
                    color: AppTheme.slate500,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _ageLabel(entry.createdAt),
            style: AppTheme.ts(11, FontWeight.w700, color: AppTheme.slate400),
          ),
        ],
      ),
    );
  }
}

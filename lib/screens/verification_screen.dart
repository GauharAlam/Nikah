// Verification screen — Barkat-style centered trust header with the gold
// "Barkat Verified" pill, benefits list, per-document cards and FAQs.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verification_doc.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';

/// Full-screen verification checklist (route: /profile/verify).
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<VerificationDoc> docs = store.verificationDocs;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Verification',
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
        children: <Widget>[
          // ── Centered trust-signal header ────────────────────────────────
          Center(
            child: Text(
              'YOUR TRUST SIGNAL',
              style: AppTheme.ts(
                10,
                FontWeight.w800,
                color: AppTheme.green,
              ).copyWith(letterSpacing: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get the Barkat Verified Badge',
            textAlign: TextAlign.center,
            style: AppTheme.ts(21, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 8),
          Text(
            store.isBarkatVerified
                ? 'MashaAllah — every required document is approved. Your '
                      'badge is live on your profile.'
                : 'Verify your profile to earn the Barkat Verified badge — '
                      'a mark of trust that members recognise instantly.',
            textAlign: TextAlign.center,
            style: AppTheme.ts(
              12.5,
              FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.goldAccent.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: AppTheme.goldInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Barkat Verified',
                    style: AppTheme.ts(11.5, FontWeight.w800, color: AppTheme.goldInk),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Text(
              '${store.verificationProgress}% complete',
              style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate500),
            ),
          ),
          const SizedBox(height: 19),

          // ── Why verify ──────────────────────────────────────────────────
          const _BenefitRow(
            icon: Icons.verified_user_outlined,
            title: 'Prove you are who you say you are',
            body: 'ID and education documents reviewed by our team.',
          ),
          const _BenefitRow(
            icon: Icons.trending_up_rounded,
            title: 'Move up in search results',
            body: 'Verified profiles rank higher for serious seekers.',
          ),
          const _BenefitRow(
            icon: Icons.favorite_outline_rounded,
            title: 'Build confidence with serious seekers',
            body: 'Members reach verified profiles first.',
            last: true,
          ),
          const SizedBox(height: 20),

          // ── Steps ───────────────────────────────────────────────────────
          SectionLabel('Verification Steps'),
          const SizedBox(height: 4),
          Text(
            'Upload your documents below to complete verification.',
            style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500),
          ),
          const SizedBox(height: 12),
          for (final VerificationDoc doc in docs) ...<Widget>[
            _DocCard(
              doc: doc,
              onTap: () {
                if (doc.status == VerificationDocStatus.missing) {
                  store.submitVerificationDoc(doc.id);
                  showSuccessSnack(
                    context,
                    '${doc.title} uploaded — our team will review it.',
                  );
                } else if (doc.status == VerificationDocStatus.pending) {
                  showAppSnack(
                    context,
                    '${doc.title} is waiting for review by the Barkat team.',
                    icon: Icons.hourglass_bottom_rounded,
                  );
                } else {
                  showAppSnack(
                    context,
                    '${doc.title} is already approved.',
                    icon: Icons.verified_rounded,
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),

          // ── Good to know ────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Good to know',
                  style: AppTheme.ts(14, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 12),
                const _KnowRow(
                  icon: Icons.image_outlined,
                  text: 'Clear, well-lit photos. Any image up to 10 MB.',
                ),
                const _KnowRow(
                  icon: Icons.schedule_outlined,
                  text: 'Usually reviewed within 24–48 hours.',
                ),
                const _KnowRow(
                  icon: Icons.lock_outline_rounded,
                  text: 'Documents stay private and are never shared with '
                      'members.',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon in a circle + title/body used in the "why verify" list.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppTheme.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTheme.ts(13, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTheme.ts(
                    11.5,
                    FontWeight.w500,
                    color: AppTheme.slate500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Document card with tinted icon square, status detail and an affordance
/// on the right (Upload › / View › / green check when verified).
class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.onTap});

  final VerificationDoc doc;
  final VoidCallback onTap;

  static IconData _iconFor(String id) => switch (id) {
        'name-proof' => Icons.badge_outlined,
        'education-proof' => Icons.school_outlined,
        'photo-proof' => Icons.photo_camera_outlined,
        'income-proof' => Icons.account_balance_wallet_outlined,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final bool approved = doc.status == VerificationDocStatus.approved;
    final bool pending = doc.status == VerificationDocStatus.pending;
    final Color fg = approved
        ? AppTheme.success
        : (pending ? AppTheme.warning : AppTheme.slate500);
    final Color iconField = approved
        ? AppTheme.successBg
        : AppTheme.mint.withValues(alpha: 0.3);

    return AppCard(
      key: Key('verification_doc_${doc.id}'),
      backgroundColor: approved ? AppTheme.successBg : null,
      borderColor: approved
          ? AppTheme.sage.withValues(alpha: 0.5)
          : AppTheme.slate200.withValues(alpha: 0.8),
      padding: const EdgeInsets.all(13),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconField,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _iconFor(doc.id),
                size: 21,
                color: approved ? AppTheme.success : AppTheme.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    doc.title,
                    style: AppTheme.ts(
                      13.5,
                      FontWeight.w800,
                      color: AppTheme.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.subtitle,
                    style: AppTheme.ts(
                      11.5,
                      FontWeight.w500,
                      color: AppTheme.slate500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    doc.status.detail,
                    style: AppTheme.ts(11, FontWeight.w700, color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (approved)
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    pending ? 'View' : 'Upload',
                    style: AppTheme.ts(12, FontWeight.w800, color: AppTheme.green),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: AppTheme.green,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _KnowRow extends StatelessWidget {
  const _KnowRow({required this.icon, required this.text, this.last = false});

  final IconData icon;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: AppTheme.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: AppTheme.ts(
                  12,
                  FontWeight.w500,
                  color: AppTheme.slate600,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

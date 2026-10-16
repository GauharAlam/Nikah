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

/// Final onboarding review — summarises every section and submits the
/// biodata for guardian verification.
class ReviewStepScreen extends StatefulWidget {
  const ReviewStepScreen({super.key});

  @override
  State<ReviewStepScreen> createState() => _ReviewStepScreenState();
}

class _ReviewStepScreenState extends State<ReviewStepScreen> {
  bool _pledged = false;
  bool _submitting = false;

  Future<void> _submit() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.read<AppStore>().submitOnboarding();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2600),
          backgroundColor: AppTheme.emerald,
          content: Row(
            children: <Widget>[
              const Icon(Icons.verified_user_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Biodata submitted — awaiting your Wali\'s blessing, in sha '
                  'Allah.',
                  style: AppTheme.ts(13, FontWeight.w600,
                      color: Colors.white, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    context.go(AppRoutes.homeDiscovery);
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final WardProfile profile = store.profile ?? WardProfile.demoWard;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Flexible(
              child: Text(
                'Review Biodata',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.goldAccent.withValues(alpha: 0.55)),
              ),
              child: Text(
                'FINAL',
                style: AppTheme.ts(9.5, FontWeight.w800,
                    color: AppTheme.goldDeep, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: <Widget>[
          _SummaryCard(
            icon: Icons.person_outline_rounded,
            title: 'Account',
            onEdit: () => context.push(AppRoutes.onboardingAccount),
            rows: <(String, String)>[
              ('Name', profile.displayName.isEmpty
                  ? 'Amina Al-Mansoor'
                  : profile.displayName),
              ('Gender', profile.gender.label),
              ('Age', profile.age == null ? '—' : '${profile.age} years'),
              ('Searching for', profile.mode.label),
            ],
          ),
          _SummaryCard(
            icon: Icons.phone_iphone_rounded,
            title: 'Credentials',
            onEdit: () => context.push(AppRoutes.onboardingAccount),
            rows: <(String, String)>[
              ('Phone', '${profile.phoneCode} ${profile.phone}'.trim()),
              ('Email', _maskEmail(profile.email)),
            ],
          ),
          _SummaryCard(
            icon: Icons.mosque_outlined,
            title: 'Deen & practice',
            onEdit: () => context.push(AppRoutes.onboardingPractice),
            rows: <(String, String)>[
              ('Prayer', profile.prayerFrequency.label),
              ('Qur\'an', profile.quranComfort.label),
              ('Timeline', profile.timeline),
              ('Relocation', profile.relocation),
            ],
            chips: profile.halalLifestyle,
          ),
          _SummaryCard(
            icon: Icons.verified_user_outlined,
            title: 'Wali / Guardian',
            onEdit: () => context.push(AppRoutes.onboardingWali),
            rows: <(String, String)>[
              ('Name', store.guardian.name),
              ('Relationship', store.guardian.relation.label),
              (
                'Phone',
                '${store.guardian.phoneCode} ${store.guardian.phone}'.trim(),
              ),
            ],
            footer: store.guardian.isVerified
                ? null
                : const InfoBanner(
                    icon: Icons.hourglass_top_rounded,
                    text: 'Guardian verification completes via the 6-digit '
                        'SMS portal after submission.',
                    variant: InfoVariant.warning,
                    tight: true,
                  ),
          ),
          _SummaryCard(
            icon: Icons.badge_outlined,
            title: 'Biodata',
            onEdit: () => context.push(AppRoutes.onboardingBiodata),
            rows: <(String, String)>[
              ('City', profile.city.isEmpty ? '—' : profile.city),
              ('Country', profile.country.isEmpty ? '—' : profile.country),
              ('Education', profile.education.isEmpty ? '—' : profile.education),
              (
                'Profession',
                profile.profession.isEmpty ? '—' : profile.profession,
              ),
            ],
            paragraph: profile.aboutMe.isEmpty ? null : profile.aboutMe,
          ),
          const SizedBox(height: 6),
          const InfoBanner(
            icon: Icons.handshake_outlined,
            text: 'I affirm this biodata is truthful and I have my Wali\'s '
                'consent to proceed with guardianship-supervised '
                'introductions.',
            variant: InfoVariant.warning,
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _submitting
                  ? null
                  : () => setState(() => _pledged = !_pledged),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: _pledged,
                      onChanged: _submitting
                          ? null
                          : (bool? v) => setState(() => _pledged = v ?? false),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'I pledge sincerely, for the sake of Allah.',
                        style: AppTheme.ts(13.5, FontWeight.w700,
                            color: AppTheme.slate800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _submitting
                ? 'Submitting…'
                : 'Submit for Guardian Verification',
            icon: Icons.verified_rounded,
            progress: _submitting,
            onPressed: _pledged ? _submit : null,
          ),
        ],
      ),
    );
  }

  static String _maskEmail(String email) {
    final int at = email.indexOf('@');
    if (at <= 0) return email.isEmpty ? '—' : email;
    final String head = email.substring(0, at);
    final String domain = email.substring(at);
    final String masked =
        head.length <= 2 ? '${head[0]}***' : '${head[0]}***${head[head.length - 1]}';
    return '$masked$domain';
  }
}

/// One review section with edit affordance, label/value rows, optional
/// chips and paragraph.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.rows,
    required this.onEdit,
    this.chips = const <String>[],
    this.paragraph,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;
  final List<String> chips;
  final String? paragraph;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppTheme.slate700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: AppTheme.ts(14.5, FontWeight.w800,
                        color: AppTheme.slate900)),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 108,
                    child: Text(
                      label,
                      style: AppTheme.ts(12, FontWeight.w600,
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
            ),
          if (chips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: chips.map<Widget>((String c) => TagChip(c)).toList(),
            ),
          ],
          if (paragraph != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              paragraph!,
              style: AppTheme.ts(13, FontWeight.w500,
                  color: AppTheme.slate600, height: 1.5),
            ),
          ],
          if (footer != null) ...<Widget>[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
  }
}

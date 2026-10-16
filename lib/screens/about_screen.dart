import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';

/// About & Help: brand story, FAQs, support contacts and legal rows.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('About & Help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 60),
        children: <Widget>[
          const _BrandHero(),
          const SizedBox(height: 22),
          const SectionLabel('Frequently asked'),
          const SizedBox(height: 10),
          const _FaqTile(
            question: 'What is a Wali?',
            answer:
                'The Wali is the guardian appointed by Islamic law to '
                'safeguard a woman\'s interests in marriage (Qur\'an 4:34; '
                'the Prophet ﷺ said: "There is no nikah without a wali"). On '
                'Barkat Nikah, every account links to a Wali who reviews '
                'introductions, oversees conversations and approves family '
                'meetings.',
          ),
          const _FaqTile(
            question: 'How is chaperoned chat supervised?',
            answer:
                'Every conversation is visible to both guardians and archived '
                'for the audit log. Messages are etiquette-checked for adab, '
                'and no private exchange is possible before nikah — this '
                'protects the dignity of both families.',
          ),
          const _FaqTile(
            question: 'Can I browse as a guest?',
            answer:
                'Yes — guests can explore the discovery deck with modesty '
                'blur active. Sending introductions and opening chat requires '
                'a full account with a verified Wali.',
          ),
          const _FaqTile(
            question: 'How do I report a concern?',
            answer:
                'Use any contact channel below. Our scholar-supervised team '
                'responds within 24 hours and can escalate serious matters to '
                'the community panel immediately.',
          ),
          const SizedBox(height: 22),
          const SectionLabel('Reach the support desk'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onTap: () => showAppSnack(
                    context,
                    'Jazak Allah khayr — the support desk replies within 24h.',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  onTap: () => showAppSnack(
                    context,
                    'Jazak Allah khayr — the support desk replies within 24h.',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.rate_review_outlined,
                  label: 'Feedback',
                  onTap: () => showAppSnack(
                    context,
                    'Jazak Allah khayr — the support desk replies within 24h.',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Legal & guidelines'),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How your biodata is protected',
            onTap: () => showAppSnack(
              context,
              'Full document ships with the release, in sha Allah.',
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.gavel_rounded,
            title: 'Community Guidelines',
            subtitle: 'Adab-first conduct for every member',
            onTap: () => showAppSnack(
              context,
              'Full document ships with the release, in sha Allah.',
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.menu_book_outlined,
            title: 'Qur\'an 30:21 — our founding verse',
            subtitle: 'Reflection on sakinah, mawaddah & rahmah',
            onTap: () => showAppSnack(
              context,
              'A fuller tafseer reading list ships soon, in sha Allah.',
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'In sha Allah — built with adab.',
              style: AppTheme.ts(12, FontWeight.w600,
                  color: AppTheme.slate400),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.brandWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.6), width: 1.5),
            ),
            child: const Icon(Icons.mosque, color: AppTheme.gold, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Barkat Nikah',
            style: AppTheme.ts(21, FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'بركة نكاح',
            style: AppTheme.ts(15, FontWeight.w700,
                color: AppTheme.gold.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 10),
          Text(
            'Dignity-first Islamic matrimony — guardian supervised, '
            'adab protected, barakah built.',
            textAlign: TextAlign.center,
            style: AppTheme.ts(12.5, FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.82), height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              'v1.0.0+1',
              style: AppTheme.ts(10.5, FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppTheme.green,
          collapsedIconColor: AppTheme.slate400,
          title: Text(
            question,
            style:
                AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900),
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: AppTheme.ts(12.5, FontWeight.w500,
                    color: AppTheme.slate600, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: AppTheme.green),
          const SizedBox(height: 7),
          Text(
            label,
            style:
                AppTheme.ts(12, FontWeight.w700, color: AppTheme.slate800),
          ),
        ],
      ),
    );
  }
}

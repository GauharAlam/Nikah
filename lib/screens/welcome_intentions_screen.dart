// Marketing welcome screen: hero verse, the four pillars of sacred
// matrimony, social proof, and the primary signup CTAs.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';

class WelcomeIntentionsScreen extends StatelessWidget {
  const WelcomeIntentionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const <Widget>[
          _VerseHero(),
          SizedBox(height: 22),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _PillarsSection(),
          ),
          SizedBox(height: 22),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SocialProofCard(),
          ),
          SizedBox(height: 22),
          _CtaColumn(),
          _FooterNote(),
        ],
      ),
    );
  }
}

class _VerseHero extends StatelessWidget {
  const _VerseHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const AppNetworkImage(
            url: 'https://images.unsplash.com/photo-1560250097-0b93528c311a'
                '?q=80&w=800&auto=format&fit=crop',
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppTheme.emeraldDeep.withValues(alpha: 0.35),
                  AppTheme.emeraldDeep.withValues(alpha: 0.55),
                  AppTheme.emeraldDeep,
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BARKAT NIKAH · بركة نكاح',
                  style: AppTheme.ts(11, FontWeight.w800, color: AppTheme.gold,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 14),
                Text(
                  'وَجَعَلَ بَيْنَكُم مَّوَدَّةً وَرَحْمَةً',
                  style: AppTheme.ts(22, FontWeight.w600, color: AppTheme.gold,
                      height: 1.9),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 10),
                Text(
                  '"And among His signs is that He created for you spouses '
                  'from among yourselves, that you may find tranquility in '
                  'them; and He placed between you affection and mercy." '
                  '— Quran 30:21',
                  style: AppTheme.ts(
                    13.5,
                    FontWeight.w400,
                    color: AppTheme.gold,
                    height: 1.55,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.shield_outlined, size: 14, color: AppTheme.gold),
                      const SizedBox(width: 6),
                      Text(
                        'Every introduction chaperoned',
                        style: AppTheme.ts(11, FontWeight.w700, color: Colors.white),
                      ),
                    ],
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

class _PillarsSection extends StatelessWidget {
  const _PillarsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pillars of Sacred Matrimony'.toUpperCase(),
          style: AppTheme.overline,
        ),
        const SizedBox(height: 6),
        Text('Built on Quran, guarded by family', style: AppTheme.h2),
        const SizedBox(height: 16),
        const _Pillar(
          icon: Icons.handshake_outlined,
          title: 'Ta\'aruf with dignity',
          body: 'Meet through respectful, structured introductions — no '
              'endless swiping, no pressure, only sincere intention.',
        ),
        const _Pillar(
          icon: Icons.shield_outlined,
          title: 'Wali oversight',
          body: 'Your guardian reviews biodata and approves each step, '
              'guided by the etiquette of Quran 4:34 and family wisdom.',
        ),
        const _Pillar(
          icon: Icons.favorite_outlined,
          title: 'Sakinah & Mawaddah',
          body: 'Our purpose is a marriage of tranquility, affection and '
              'mercy — the home the Quran describes, not a market.',
        ),
        const _Pillar(
          icon: Icons.forum_outlined,
          title: 'Chaperoned communication',
          body: 'Conversations open only after both guardians approve, and '
              'remain supervised and archived throughout.',
        ),
      ],
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Icon(icon, size: 20, color: AppTheme.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTheme.h3),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialProofCard extends StatelessWidget {
  const _SocialProofCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: AppTheme.emeraldDeep,
      borderColor: AppTheme.emerald,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '2,400+ families built with barakah',
            style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.gold),
          ),
          const SizedBox(height: 4),
          Text(
            'Across the UK, Gulf and South Asian communities.',
            style: AppTheme.ts(12.5, FontWeight.w500, color: AppTheme.gold),
          ),
          const SizedBox(height: 16),
          Row(
            children: const <Widget>[
              Expanded(child: _Stat(value: '98%', label: 'Wali verified')),
              SizedBox(width: 10),
              Expanded(child: _Stat(value: '1:1', label: 'Chaperone ratio')),
              SizedBox(width: 10),
              Expanded(child: _Stat(value: '217', label: 'Nikahs in 2026')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.gold),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTheme.ts(10, FontWeight.w600, color: AppTheme.gold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CtaColumn extends StatelessWidget {
  const _CtaColumn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(
            label: 'Begin My Journey',
            icon: Icons.favorite_rounded,
            onPressed: () {
              context.read<AppStore>().enterOnboarding();
              context.push(AppRoutes.onboardingAccount);
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.signIn),
            child: Text(
              'I Already Have an Account',
              style: AppTheme.ts(14, FontWeight.w700, color: AppTheme.emerald),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AppStore>().signInAsGuest();
              context.go(AppRoutes.homeDiscovery);
            },
            child: Text(
              'Explore profiles quietly as a guest',
              style: AppTheme.ts(13, FontWeight.w700, color: AppTheme.slate500),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      child: Column(
        children: <Widget>[
          Divider(color: AppTheme.slate200),
          const SizedBox(height: 14),
          Text(
            'Photos are modesty-first: portraits remain blurred for '
            'non-verified accounts until your guardian approves viewing. '
            'May every journey begin and end with barakah.',
            style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '© 2026 Barkat Nikah · Dignity-first halal matrimony',
            style: AppTheme.ts(11, FontWeight.w700, color: AppTheme.slate400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

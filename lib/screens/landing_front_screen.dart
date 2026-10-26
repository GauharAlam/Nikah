// Sign-up front door screen — Barkat-style editorial landing: cream canvas,
// logo lockup, gold seal, hero photo with campus chips, trust row and the
// account creation form.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_brand.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';

enum _AuthMethod { phone, email }

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: const <Widget>[
            _TopBar(),
            SizedBox(height: 24),
            _HeroCopy(),
            SizedBox(height: 18),
            _HeroCard(),
            SizedBox(height: 12),
            _TrustLine(),
            SizedBox(height: 18),
            _ValueProps(),
            SizedBox(height: 20),
            _SignupForm(),
            SizedBox(height: 18),
            _FooterNote(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        BarkatLockup(),
        Spacer(),
        GoldSeal(size: 44),
      ],
    );
  }
}

/// "Where educated Muslims meet for Nikah" headline block.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'PREMIUM MATRIMONY PLATFORM',
          style: AppTheme.ts(
            10,
            FontWeight.w800,
            color: AppTheme.goldDeep,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Where educated\nMuslims meet for '),
              TextSpan(
                text: 'Nikah',
                style: AppTheme.ts(31, FontWeight.w800, color: AppTheme.green),
              ),
            ],
          ),
          style: AppTheme.ts(31, FontWeight.w800, color: AppTheme.slate900, height: 1.16),
        ),
        const SizedBox(height: 12),
        Text(
          'From AMU to Harvard — a family-first platform for graduates who '
          'want marriage with clarity, not endless browsing.',
          style: AppTheme.ts(13.5, FontWeight.w500, color: AppTheme.slate600, height: 1.5),
        ),
      ],
    );
  }
}

/// Editorial photo card with campus chips, mirroring the marketing art.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Decorative hero. Empty until a licensed asset is supplied.
            const AppNetworkImage(url: ''),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const <double>[0, 0.45, 0.8],
                  colors: <Color>[
                    AppTheme.emeraldDeep.withValues(alpha: 0.88),
                    AppTheme.emeraldDeep.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.verified_rounded,
                        size: 12, color: AppTheme.goldInk),
                    const SizedBox(width: 4),
                    Text(
                      'Graduates+ only',
                      style: AppTheme.ts(10, FontWeight.w800, color: AppTheme.goldInk),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AMU to Harvard, everyone is here.',
                    style: AppTheme.ts(15, FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const <Widget>[
                      CampusChip('AMU'),
                      CampusChip('Jamia'),
                      CampusChip('IIT'),
                      CampusChip('DU'),
                      CampusChip('Harvard'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "✓ Manually reviewed profiles | 100% Secure" trust strip.
class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.green),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Manually reviewed profiles',
            style: AppTheme.ts(12, FontWeight.w700, color: AppTheme.slate700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('|', style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate400)),
        ),
        const Icon(Icons.lock_rounded, size: 14, color: AppTheme.green),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '100% Secure',
            style: AppTheme.ts(12, FontWeight.w700, color: AppTheme.slate700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The three Barkat value props: alma mater, manual review, human support.
class _ValueProps extends StatelessWidget {
  const _ValueProps();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: const <Widget>[
          _ValueRow(
            icon: Icons.school_outlined,
            title: 'Alma mater filter',
            detail: 'Search by campus — Jamia, AMU, IIT, DU and more.',
          ),
          SizedBox(height: 12),
          _ValueRow(
            icon: Icons.fact_check_outlined,
            title: 'Reviewed by a real team',
            detail: 'Identity and education checked before a profile goes live.',
          ),
          SizedBox(height: 12),
          _ValueRow(
            icon: Icons.support_agent_rounded,
            title: 'Personalised support',
            detail: 'A specialist helps your family take the next clear step.',
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.successBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppTheme.green),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTheme.ts(13.5, FontWeight.w800, color: AppTheme.slate900),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignupForm extends StatefulWidget {
  const _SignupForm();

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  _AuthMethod _method = _AuthMethod.phone;

  late final TextEditingController _phoneController =
      TextEditingController(text: '7700 900189');
  late final TextEditingController _emailController =
      TextEditingController(text: 'amina@example.com');
  late final TextEditingController _passwordController =
      TextEditingController(text: 'Barakah2026*Sacred');

  String _countryCode = '+44';

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your phone number';
    if (value.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email address';
    if (!value.trim().contains('@')) return 'Enter a valid email address';
    return null;
  }

  void _submit() {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      showAppSnack(
        context,
        'Please review the highlighted fields',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    context.read<AppStore>().enterOnboarding();
    context.push(AppRoutes.onboardingAccount);
  }

  void _exploreAsGuest() {
    context.read<AppStore>().signInAsGuest();
    context.go(AppRoutes.homeDiscovery);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Create your profile',
              style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
            ),
            const SizedBox(height: 3),
            Text(
              'Free to join. Every profile is reviewed before it goes live.',
              style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
            ),
            const SizedBox(height: 14),
            AppSegmentedToggle<_AuthMethod>(
              selected: _method,
              onChanged: (_AuthMethod next) => setState(() => _method = next),
              options: const <SegmentedOption<_AuthMethod>>[
                SegmentedOption<_AuthMethod>(
                  value: _AuthMethod.phone,
                  label: 'Phone',
                  icon: Icons.phone_iphone_rounded,
                ),
                SegmentedOption<_AuthMethod>(
                  value: _AuthMethod.email,
                  label: 'Email',
                  icon: Icons.alternate_email_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_method == _AuthMethod.phone) ...<Widget>[
              const SectionLabel('Mobile number', requiredMark: true),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  AppCountryField(
                    value: _countryCode,
                    onChanged: (String code) => setState(() => _countryCode = code),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      label: 'Number',
                      controller: _phoneController,
                      hint: '7700 000000',
                      icon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              AppTextField(
                label: 'Email address',
                controller: _emailController,
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 14),
            PasswordField(
              label: 'Password',
              controller: _passwordController,
              hint: 'Minimum 8 characters',
              validator: _validatePassword,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 6),
            const InfoBanner(
              tight: true,
              variant: InfoVariant.neutral,
              icon: Icons.bolt_rounded,
              text: 'Demo data pre-filled — just tap Continue.',
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Create My Account',
              icon: Icons.favorite_rounded,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.signIn),
              child: const Text('Already a member? Sign In'),
            ),
            OutlinedButton(
              onPressed: _exploreAsGuest,
              child: Text(
                'Explore Profiles as Guest',
                style: AppTheme.ts(14, FontWeight.w700, color: AppTheme.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'Manually reviewed · Family-first · Halal intent',
          style: AppTheme.ts(11.5, FontWeight.w700, color: AppTheme.goldDeep),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '© 2026 Barkat Nikah · Premium educated Muslim matrimony',
          style: AppTheme.ts(11, FontWeight.w600, color: AppTheme.slate400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

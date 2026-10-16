// Sign-in screen for returning members, including SMS-2FA status,
// biometric shortcut, and the Wali portal callout.
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
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';

enum _AuthMethod { phone, email }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  _AuthMethod _method = _AuthMethod.phone;

  final TextEditingController _phoneController =
      TextEditingController(text: '7700 900189');
  final TextEditingController _emailController =
      TextEditingController(text: 'amina@example.com');
  final TextEditingController _passwordController =
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
    if (value == null || value.isEmpty) return 'Enter your password';
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

  void _signIn() {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      showAppSnack(
        context,
        'Please review the highlighted fields',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final String email = _emailController.text.trim();
    final String phone = _countryCode == '+44'
        ? _phoneController.text.trim()
        : '$_countryCode ${_phoneController.text.trim()}';
    context.read<AppStore>().signIn(
          email: _method == _AuthMethod.email ? email : null,
          phone: _method == _AuthMethod.phone ? phone : null,
        );
    showSuccessSnack(context, 'Two-factor verified. Wa alaikum as-salam!');
    context.go(AppRoutes.homeDiscovery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.cream,
        title: const Text('Sign In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: <Widget>[
            const BarkatLockup(),
            const SizedBox(height: 18),
            Text('Welcome back', style: AppTheme.h1),
            const SizedBox(height: 6),
            Text(
              'Amina, resume your chaperoned introductions. Your guardian '
              'keeps the same oversight as before — nothing moves without '
              'barakah and blessing.',
              style: AppTheme.body,
            ),
            const SizedBox(height: 20),
            _CredentialsForm(
              formKey: _formKey,
              method: _method,
              onMethodChanged: (_AuthMethod next) => setState(() => _method = next),
              phoneController: _phoneController,
              emailController: _emailController,
              passwordController: _passwordController,
              countryCode: _countryCode,
              onCountryChanged: (String code) =>
                  setState(() => _countryCode = code),
              validatePassword: _validatePassword,
              validatePhone: _validatePhone,
              validateEmail: _validateEmail,
              onSubmit: _signIn,
            ),
            const SizedBox(height: 14),
            _SecurityRow(onBiometric: _signIn),
            const SizedBox(height: 14),
            const _WaliCallout(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.read<AppStore>().enterOnboarding();
                context.push(AppRoutes.onboardingAccount);
              },
              child: const Text('New here? Create your account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialsForm extends StatelessWidget {
  const _CredentialsForm({
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.countryCode,
    required this.onCountryChanged,
    required this.validatePassword,
    required this.validatePhone,
    required this.validateEmail,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final _AuthMethod method;
  final ValueChanged<_AuthMethod> onMethodChanged;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String countryCode;
  final ValueChanged<String> onCountryChanged;
  final String? Function(String?) validatePassword;
  final String? Function(String?) validatePhone;
  final String? Function(String?) validateEmail;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSegmentedToggle<_AuthMethod>(
              selected: method,
              onChanged: onMethodChanged,
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
            if (method == _AuthMethod.phone) ...<Widget>[
              const SectionLabel('Mobile number', requiredMark: true),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  AppCountryField(
                    value: countryCode,
                    onChanged: onCountryChanged,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      label: 'Number',
                      controller: phoneController,
                      hint: '7700 000000',
                      icon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      validator: validatePhone,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              AppTextField(
                label: 'Email address',
                controller: emailController,
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 14),
            PasswordField(
              label: 'Password',
              controller: passwordController,
              hint: 'Minimum 8 characters',
              validator: validatePassword,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Sign In Securely',
              icon: Icons.lock_rounded,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.onBiometric});

  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InfoBanner(
            tight: true,
            variant: InfoVariant.success,
            icon: Icons.sms_outlined,
            text: 'SMS 2FA active — codes arrive from your guardian line.',
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.green,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.slate900.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Unlock with biometrics',
            onPressed: onBiometric,
            icon: const Icon(Icons.fingerprint, size: 26, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _WaliCallout extends StatelessWidget {
  const _WaliCallout();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: Colors.white,
      borderColor: AppTheme.goldAccent.withValues(alpha: 0.6),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.goldAccent),
              const SizedBox(width: 8),
              Text(
                'Are you the Wali?',
                style: AppTheme.ts(15, FontWeight.w800, color: AppTheme.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Khalid Al-Mansoor, oversee approval of introductions, message '
            'audits and the family meeting calendar from the guardian portal.',
            style: AppTheme.ts(12.5, FontWeight.w500, color: AppTheme.slate600, height: 1.45),
          ),
          const SizedBox(height: 14),
          PositiveOutlinedButton(
            label: 'Open Wali Portal',
            icon: Icons.admin_panel_settings_outlined,
            onPressed: () => context.push(AppRoutes.waliPortal),
          ),
        ],
      ),
    );
  }
}

/// Onboarding step 1 — account mode, member credentials and honor pledge.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';
import '../widgets/onboarding_shell.dart';

part 'create_account_widgets.dart';

class CreateAccountStepScreen extends StatefulWidget {
  const CreateAccountStepScreen({super.key});

  @override
  State<CreateAccountStepScreen> createState() =>
      _CreateAccountStepScreenState();
}

class _CreateAccountStepScreenState extends State<CreateAccountStepScreen> {
  static const String _demoName = 'Zainab Al-Mansoor';
  static const String _demoPhone = '7700 900189';
  static const String _demoPassword = 'Barakah2026*Sacred';
  static const List<String> _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _dobController;

  AccountFor _mode = AccountFor.myself;
  Gender _gender = Gender.female;
  DateTime? _dob;
  String _phoneCode = '+44';
  int _strength = 0;

  bool _pledgeIntention = false;
  bool _pledgeConsent = false;
  bool _pledgeTruth = false;

  bool get _allPledged => _pledgeIntention && _pledgeConsent && _pledgeTruth;

  @override
  void initState() {
    super.initState();
    final WardProfile? draft = context.read<AppStore>().profile;
    _mode = draft?.mode ?? AccountFor.myself;
    _gender = draft?.gender ?? Gender.female;
    _dob = draft?.dateOfBirth;
    _phoneCode = (draft?.phoneCode.isEmpty ?? true) ? '+44' : draft!.phoneCode;
    final String savedName = draft?.displayName ?? '';
    final String savedPhone = draft?.phone ?? '';
    _nameController = TextEditingController(
      text: savedName.isEmpty ? _demoName : savedName,
    );
    _emailController = TextEditingController(text: draft?.email ?? '');
    _phoneController = TextEditingController(
      text: savedPhone.isEmpty ? _demoPhone : savedPhone,
    );
    _passwordController = TextEditingController(text: _demoPassword);
    _strength = _strengthScore(_passwordController.text);
    _passwordController.addListener(_onPasswordChanged);
    _dobController = TextEditingController(text: _fmtDob(_dob));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final int next = _strengthScore(_passwordController.text);
    if (next != _strength) setState(() => _strength = next);
  }

  static int _strengthScore(String text) {
    if (text.isEmpty) return 0;
    final bool hasDigit = text.contains(RegExp(r'\d'));
    final bool hasSymbol = text.contains(RegExp(r'[^A-Za-z0-9]'));
    if (text.length >= 12 && hasDigit && hasSymbol) return 4;
    if (text.length >= 10 && hasDigit) return 3;
    if (text.length >= 8) return 2;
    return 1;
  }

  static String _fmtDob(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
  }

  int? get _age {
    final DateTime? dob = _dob;
    if (dob == null) return null;
    final DateTime now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  Future<void> _pickDob() async {
    final DateTime first = DateTime(1960);
    final DateTime last = DateTime(2008, 12, 31);
    DateTime initial = _dob ?? DateTime(1997, 6, 14);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Date of birth',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobController.text = _fmtDob(picked);
    });
  }

  void _changeMode(AccountFor next) {
    setState(() => _mode = next);
    context.read<AppStore>().updateProfile((WardProfile p) => p.copyWith(mode: next));
  }

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your full name';
    if (name.length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  String? _validateDob(String? _) =>
      _dob == null ? 'Select your date of birth' : null;

  String? _validatePhone(String? value) {
    final String phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter your phone number';
    return RegExp(r'\d').allMatches(phone).length >= 7
        ? null
        : 'Enter a valid phone number';
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Create a password';
    if (password.length < 8) return 'Password must be at least 8 characters';
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
    context
        .read<AppStore>()
        ..updateProfile(
          (WardProfile p) => p.copyWith(
            displayName: _nameController.text.trim(),
            mode: _mode,
            gender: _gender,
            dateOfBirth: _dob,
            phoneCode: _phoneCode,
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          ),
        )
        ..markStepDone(1);
    showSuccessSnack(context, 'Account saved. Barakallahu feek!');
    context.push(AppRoutes.onboardingEducation);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle hint = AppTheme.ts(10.5, FontWeight.w600, color: AppTheme.slate500);
    return OnboardingShell(
      step: 1,
      title: 'Create Account',
      subtitle: 'Begin with sincere intentions and secure credentials.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const InfoBanner(
              variant: InfoVariant.gold,
              icon: Icons.volunteer_activism_outlined,
              text: 'Begin with Bismillah. This account is for a sincere '
                  'halal Nikah — your details stay private until a '
                  'Wali-verified match.',
            ),
            const SizedBox(height: 22),
            const SectionLabel('Who is this account for?', requiredMark: true),
            const SizedBox(height: 8),
            AppSegmentedToggle<AccountFor>(
              selected: _mode,
              onChanged: _changeMode,
              options: const <SegmentedOption<AccountFor>>[
                SegmentedOption<AccountFor>(value: AccountFor.myself, label: 'Myself', icon: Icons.person_outline_rounded),
                SegmentedOption<AccountFor>(value: AccountFor.daughterSister, label: 'Daughter / Sister', icon: Icons.woman_outlined),
                SegmentedOption<AccountFor>(value: AccountFor.sonBrother, label: 'Son / Brother', icon: Icons.man_outlined),
              ],
            ),
            const SizedBox(height: 7),
            Text(_mode.detail, style: AppTheme.bodySmall),
            const SizedBox(height: 22),
            const SectionLabel('Member details', requiredMark: true),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppTextField(
                    label: 'Full name', controller: _nameController,
                    hint: 'Zainab Al-Mansoor', icon: Icons.badge_outlined,
                    validator: _validateName, textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 6),
                  Text('Kept private until a Wali-verified match.', style: hint),
                  const SizedBox(height: 14),
                  _FieldLabel('Gender'),
                  const SizedBox(height: 7),
                  _GenderPicker(
                    selected: _gender,
                    onChanged: (Gender next) => setState(() => _gender = next),
                  ),
                  const SizedBox(height: 14),
                  _DobField(
                    controller: _dobController, age: _age,
                    validator: _validateDob, onTap: _pickDob,
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Phone'),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      AppCountryField(
                        value: _phoneCode,
                        onChanged: (String code) => setState(() => _phoneCode = code),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTextField(
                          label: 'Number', controller: _phoneController,
                          hint: '7700 900189', icon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone, textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('Used only for secure SMS verification.', style: hint),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Email (optional)', controller: _emailController,
                    hint: 'you@example.com', icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress, validator: _validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Password', requiredMark: true),
            const SizedBox(height: 8),
            PasswordField(
              label: 'Create password', controller: _passwordController,
              hint: 'Minimum 8 characters', validator: _validatePassword,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 9),
            _StrengthBar(score: _strength),
            const SizedBox(height: 22),
            const SectionLabel('Islamic honor pledge', requiredMark: true),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Marriage in Islam is half of the deen. By continuing you '
                    'affirm an oath of sincerity before Allah and this community.',
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  _PledgeRow(
                    text: 'My intention is a sincere halal Nikah for the sake of Allah.',
                    checked: _pledgeIntention,
                    onChanged: (bool v) => setState(() => _pledgeIntention = v),
                  ),
                  _PledgeRow(
                    text: 'My Wali (guardian) is aware of and consents to this search.',
                    checked: _pledgeConsent,
                    onChanged: (bool v) => setState(() => _pledgeConsent = v),
                  ),
                  _PledgeRow(
                    text: 'My biodata is truthful, modest and written with adab.',
                    checked: _pledgeTruth,
                    onChanged: (bool v) => setState(() => _pledgeTruth = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!_allPledged)
              const InfoBanner(
                tight: true,
                variant: InfoVariant.warning,
                icon: Icons.gavel_outlined,
                text: 'All three affirmations are required before continuing.',
              ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Save & Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _allPledged ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

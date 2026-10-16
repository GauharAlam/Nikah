/// Onboarding step 3 (or standalone guardian editor) — appoint your Wali.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';
import '../widgets/app_switch.dart';
import '../widgets/onboarding_shell.dart';

class WaliOnboardingStepScreen extends StatefulWidget {
  const WaliOnboardingStepScreen({super.key, this.isStandalone = false});

  final bool isStandalone;

  @override
  State<WaliOnboardingStepScreen> createState() =>
      _WaliOnboardingStepScreenState();
}

class _WaliOnboardingStepScreenState extends State<WaliOnboardingStepScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  GuardianRelation _relation = GuardianRelation.father;
  String _phoneCode = '+44';
  bool _introApprovals = true;
  bool _chatAudit = true;
  bool _meetingApproval = true;
  bool _inheritedVerified = false;

  @override
  void initState() {
    super.initState();
    final Guardian saved =
        context.read<AppStore>().guardian;
    final String savedName = saved.name;
    final String savedPhone = saved.phone;
    _nameController = TextEditingController(
      text: savedName.isEmpty ? 'Khalid Al-Mansoor' : savedName,
    );
    _phoneCode = saved.phoneCode.isEmpty ? '+44' : saved.phoneCode;
    _phoneController = TextEditingController(
      text: savedPhone.isEmpty ? '7700 900188' : savedPhone,
    );
    _emailController = TextEditingController(text: saved.email);
    _relation = saved.relation;
    _introApprovals = saved.allowIntroApprovals;
    _chatAudit = saved.allowChatAudit;
    _meetingApproval = saved.allowMeetingApproval;
    _inheritedVerified = saved.isVerified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _openWaliHelp() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.verified_user_outlined,
                size: 20,
                color: AppTheme.goldAccent,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('The role of a Wali', style: AppTheme.h3)),
            ],
          ),
          content: const Text(
            "In Qur'an 4:34 Allah appoints men as protectors and maintainers "
            'of the family. A Wali is the Muslim guardian — usually your '
            'father, or the next trusted mahram/scholar — who safeguards '
            'your Nikah.\n\n'
            'He reviews biodata, approves or declines introductions, receives '
            'milestone alerts and supervises correspondence, so every step '
            'stays dignified, chaperoned and halal.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Understood, bismillah'),
            ),
          ],
        );
      },
    );
  }

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) return "Enter your Wali's name";
    if (name.length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    final String phone = value?.trim() ?? '';
    if (phone.isEmpty) return "Enter your Wali's phone number";
    if (RegExp(r'\d').allMatches(phone).length < 7) {
      return 'Enter at least 7 digits';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
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
    final Guardian guardian = Guardian(
      name: _nameController.text.trim(),
      relation: _relation,
      phoneCode: _phoneCode,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      isVerified: _inheritedVerified,
      allowIntroApprovals: _introApprovals,
      allowChatAudit: _chatAudit,
      allowMeetingApproval: _meetingApproval,
    );
    final AppStore store = context.read<AppStore>();
    store.updateGuardian(guardian);
    store.markStepDone(5);
    if (widget.isStandalone) {
      showSuccessSnack(context, 'Wali details updated. Invitation re-sent.');
      context.pop();
    } else {
      showSuccessSnack(context, 'Wali appointed. Onwards to Biodata!');
      context.push(AppRoutes.onboardingBiodata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = _buildSections();
    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(
          backgroundColor: AppTheme.canvas,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Update Your Wali'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: <Widget>[
              Text('Appoint Your Wali', style: AppTheme.h2),
              const SizedBox(height: 6),
              Text(
                'Keep your guardian circle current. Your Wali supervises '
                'every introduction from the portal.',
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 22),
              ...sections,
            ],
          ),
        ),
      );
    }
    return OnboardingShell(
      step: 5,
      title: 'Appoint Your Wali',
      subtitle:
          'Every sincere search is supervised — appoint the guardian of '
          'your Nikah.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections,
      ),
    );
  }

  List<Widget> _buildSections() {
    return <Widget>[
      const InfoBanner(
        variant: InfoVariant.gold,
        icon: Icons.shield_outlined,
        text:
            "Qur'an 4:34 teaches a protected, chaperoned path to Nikah — "
            'your Wali reviews biodata, approvals and meetings.',
      ),
      const SizedBox(height: 20),
      Row(
        children: <Widget>[
          const Expanded(
            child: SectionLabel('Guardian type', requiredMark: true),
          ),
          TextButton.icon(
            onPressed: _openWaliHelp,
            icon: const Icon(
              Icons.help_outline,
              size: 17,
              color: AppTheme.green,
            ),
            label: const Text('What is a Wali?'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: GuardianRelation.values.map<Widget>((GuardianRelation r) {
            return _RelationRow(
              value: r,
              selected: _relation == r,
              onTap: () => setState(() => _relation = r),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 20),
      const SectionLabel('Guardian details', requiredMark: true),
      const SizedBox(height: 8),
      AppCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppTextField(
                label: "Wali's full name",
                controller: _nameController,
                hint: 'Khalid Al-Mansoor',
                icon: Icons.badge_outlined,
                validator: _validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              Text(
                'Phone'.toUpperCase(),
                style: AppTheme.ts(
                  10.5,
                  FontWeight.w700,
                  color: AppTheme.slate500,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  AppCountryField(
                    value: _phoneCode,
                    onChanged: (String code) =>
                        setState(() => _phoneCode = code),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      label: 'Number',
                      controller: _phoneController,
                      hint: '7700 900188',
                      icon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Guardian approvals and alerts arrive via SMS.',
                style: AppTheme.ts(
                  10.5,
                  FontWeight.w600,
                  color: AppTheme.slate500,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Email (optional)',
                controller: _emailController,
                hint: 'wali@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SectionLabel('Guardian permissions'),
      const SizedBox(height: 8),
      AppSwitchRow(
        title: 'Intro approvals',
        subtitle:
            'Each introduction request needs your Wali\'s approval first.',
        value: _introApprovals,
        onChanged: (bool v) => setState(() => _introApprovals = v),
      ),
      AppSwitchRow(
        title: 'Chat audit & milestone alerts',
        subtitle:
            'Your Wali can review chaperoned chats and receive milestone '
            'alerts.',
        value: _chatAudit,
        onChanged: (bool v) => setState(() => _chatAudit = v),
      ),
      AppSwitchRow(
        title: 'Meeting approval required',
        subtitle:
            'Family meetings must be approved by your Wali before they are '
            'scheduled.',
        value: _meetingApproval,
        onChanged: (bool v) => setState(() => _meetingApproval = v),
      ),
      const SizedBox(height: 22),
      PrimaryButton(
        label: widget.isStandalone ? 'Save Wali Details' : 'Save & Continue',
        icon: Icons.verified_user_outlined,
        onPressed: _submit,
      ),
    ];
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final GuardianRelation value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppTheme.green : AppTheme.slate400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      value.label,
                      style: AppTheme.ts(
                        13.5,
                        FontWeight.w700,
                        color: selected ? AppTheme.emeraldDeep : AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.description,
                      style: AppTheme.ts(
                        11.5,
                        FontWeight.w500,
                        color: AppTheme.slate500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

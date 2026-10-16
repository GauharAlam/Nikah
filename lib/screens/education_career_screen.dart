/// Onboarding step 2 — alma mater, degree level and career profile.
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

enum _DegreeLevel { bachelors, masters, doctorate }

extension _DegreeLevelX on _DegreeLevel {
  String get label => switch (this) {
    _DegreeLevel.bachelors => 'Bachelors',
    _DegreeLevel.masters => 'Masters',
    _DegreeLevel.doctorate => 'Doctorate',
  };
}

class EducationCareerStepScreen extends StatefulWidget {
  const EducationCareerStepScreen({super.key});

  @override
  State<EducationCareerStepScreen> createState() =>
      _EducationCareerStepScreenState();
}

class _EducationCareerStepScreenState extends State<EducationCareerStepScreen> {
  static const List<String> _universities = <String>[
    'Aligarh Muslim University (AMU)',
    'Jamia Millia Islamia',
    'IIT Delhi',
    'University of Delhi',
    'King\'s College London',
    'Imperial College London',
    'University of Oxford',
    'Harvard University',
    'Other — reviewed manually',
  ];

  late final TextEditingController _fieldController;
  late final TextEditingController _professionController;
  late final TextEditingController _employerController;

  String _almaMater = _universities.first;
  _DegreeLevel _degree = _DegreeLevel.masters;

  bool get _canContinue =>
      _almaMater.isNotEmpty && _professionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final WardProfile? draft = context.read<AppStore>().profile;
    final String savedEducation = draft?.education ?? '';
    _fieldController = TextEditingController(text: 'Computer Science');
    _professionController = TextEditingController(
      text: (draft?.profession.isEmpty ?? true)
          ? 'Community Pharmacist'
          : draft!.profession,
    );
    _employerController = TextEditingController(text: '');
    if (savedEducation.contains(' — ')) {
      final List<String> parts = savedEducation.split(' — ');
      final String uni = parts.last.trim();
      if (_universities.contains(uni)) _almaMater = uni;
      final String level = parts.first.trim();
      _degree = _DegreeLevel.values
          .firstWhere((_DegreeLevel d) => d.label == level,
              orElse: () => _DegreeLevel.masters);
    }
    _professionController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _fieldController.dispose();
    _professionController.dispose();
    _employerController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _pickUniversity() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Alma Mater',
                style:
                    AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
              ),
            ),
            for (final String u in _universities)
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  u,
                  style: AppTheme.ts(
                    14,
                    FontWeight.w600,
                    color: u == _almaMater
                        ? AppTheme.green
                        : AppTheme.slate700,
                  ),
                ),
                trailing: u == _almaMater
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppTheme.green,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(u),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _almaMater = picked);
  }

  void _submit() {
    final AppStore store = context.read<AppStore>();
    final String field = _fieldController.text.trim();
    final String degreeLine = field.isEmpty
        ? '${_degree.label} — $_almaMater'
        : '${_degree.label} in $field — $_almaMater';
    store
      ..updateProfile(
        (WardProfile p) => p.copyWith(
          education: degreeLine,
          profession: _professionController.text.trim(),
        ),
      )
      ..markStepDone(2);
    showSuccessSnack(context, 'Education & career saved.');
    context.push(AppRoutes.onboardingPractice);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 2,
      title: 'Education & Career',
      subtitle: 'Your alma mater unlocks the verified-graduate circle.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const InfoBanner(
            variant: InfoVariant.gold,
            icon: Icons.school_outlined,
            text: 'Graduates+ only — our review team checks your degree '
                'certificate during profile verification.',
          ),
          const SizedBox(height: 22),
          const SectionLabel('Alma Mater', requiredMark: true),
          const SizedBox(height: 8),
          AppCard(
            key: const Key('alma_mater_picker'),
            onTap: _pickUniversity,
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    size: 20,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _almaMater,
                    style: AppTheme.ts(
                      13.5,
                      FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppTheme.slate400,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Degree Level', requiredMark: true),
          const SizedBox(height: 8),
          AppSegmentedToggle<_DegreeLevel>(
            selected: _degree,
            onChanged: (_DegreeLevel next) => setState(() => _degree = next),
            options: const <SegmentedOption<_DegreeLevel>>[
              SegmentedOption<_DegreeLevel>(
                value: _DegreeLevel.bachelors,
                label: 'Bachelors',
                icon: Icons.school_outlined,
              ),
              SegmentedOption<_DegreeLevel>(
                value: _DegreeLevel.masters,
                label: 'Masters',
                icon: Icons.workspace_premium_outlined,
              ),
              SegmentedOption<_DegreeLevel>(
                value: _DegreeLevel.doctorate,
                label: 'Doctorate',
                icon: Icons.auto_awesome_outlined,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Field of Study'),
          const SizedBox(height: 8),
          AppCard(
            child: AppTextField(
              label: 'Field',
              controller: _fieldController,
              hint: 'e.g. Computer Science',
              icon: Icons.menu_book_outlined,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Career', requiredMark: true),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: <Widget>[
                AppTextField(
                  key: const Key('profession_field'),
                  label: 'Profession',
                  controller: _professionController,
                  hint: 'e.g. Community Pharmacist',
                  icon: Icons.work_outline_rounded,
                  validator: (String? v) => (v ?? '').trim().isEmpty
                      ? 'Enter your profession'
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Employer (optional)',
                  controller: _employerController,
                  hint: 'e.g. St Mary\'s Hospital',
                  icon: Icons.business_outlined,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Shown on your biodata as "Masters in Computer Science — AMU". '
            'Certificates are matched privately; never posted publicly.',
            style: AppTheme.ts(
              11.5,
              FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save & Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _canContinue ? _submit : null,
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../app_router.dart';
import '../../data/backend.dart';
import '../../data/option_lists.dart';
import '../../models/verification_doc.dart';
import '../../models/ward_profile.dart';
import '../../providers/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_snacks.dart';
import '../../widgets/onboarding_shell.dart';
import '../../widgets/photo_manager.dart';
import '../../widgets/picker_sheets.dart';

/// The six profile steps. Each Next saves the draft, so a member resumes
/// where they stopped, on any device.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _maxPhotos = 6;

  late WardProfile _d;
  late int _step;
  bool _busy = false;
  String? _error;
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _invite;
  late final TextEditingController _about;
  late final TextEditingController _familyBackground;
  late final TextEditingController _familyLocation;
  late final TextEditingController _career;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _d = context.read<AppStore>().profile ?? const WardProfile(phoneCode: '+91');
    _step = _d.onboardingStep.clamp(1, OnboardingShell.totalSteps);
    _name = TextEditingController(text: _d.displayName);
    _company = TextEditingController(text: _d.company);
    _invite = TextEditingController(text: _d.inviteCode);
    _about = TextEditingController(text: _d.aboutMe);
    _familyBackground = TextEditingController(text: _d.familyBackground);
    _familyLocation = TextEditingController(text: _d.familyLocation);
    _career = TextEditingController(text: _d.careerDescription);
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _invite.dispose();
    _about.dispose();
    _familyBackground.dispose();
    _familyLocation.dispose();
    _career.dispose();
    super.dispose();
  }

  void _set(WardProfile next) => setState(() {
        _d = next;
        _error = null;
      });

  WardProfile _withTyped() => _d.copyWith(
        displayName: _name.text.trim(),
        company: _company.text.trim(),
        inviteCode: _invite.text.trim().toUpperCase(),
        aboutMe: _about.text.trim(),
        familyBackground: _familyBackground.text.trim(),
        familyLocation: _familyLocation.text.trim(),
        careerDescription: _career.text.trim(),
      );

  /// What stops the current step being completed, if anything.
  String? _problem(WardProfile d) {
    final AppStore store = context.read<AppStore>();
    switch (_step) {
      case 1:
        if (d.displayName.length < 2) return 'Enter your full name.';
        if (!d.hasGender) return 'Select your gender.';
        if (d.dateOfBirth == null) return 'Select your date of birth.';
        if ((d.age ?? 0) < 18) return 'You must be at least 18.';
        if (d.maritalStatus.isEmpty) return 'Select your marital status.';
        if (d.marriageReadiness.isEmpty) return 'Select your marriage readiness.';
        if (d.maritalStatus != OptionLists.maritalStatus.first && d.children.isEmpty) {
          return 'Tell us about children.';
        }
        if (d.city.isEmpty) return 'Choose your home city.';
        if (store.verifiedPhone.isEmpty) return 'Verify your phone number.';
      case 2:
        if (d.managedBy == 'family' && !d.candidateConsent) {
          return 'Confirm that the person has agreed to this profile.';
        }
        if (d.height.isEmpty) return 'Select your height.';
      case 3:
        if (d.almaMaters.isEmpty) return 'Select your alma mater.';
        if (d.qualification.isEmpty) return 'Select your qualification.';
        if (store.graduatesOnly && OptionLists.qualifications[d.qualification] == false) {
          return tr('This community is for graduates and degree students.');
        }
        if (d.profession.isEmpty) return 'Select your profession.';
        if (!d.workSameAsHome && d.workCity.isEmpty) return 'Choose your current city.';
      case 4:
        if (d.photos.isEmpty) return 'Add at least one photo.';
      case 5:
        final VerificationDoc id = store.verificationDocs
            .firstWhere((VerificationDoc x) => x.id == 'name-proof');
        if (store.requireIdProof && id.status.needsUpload) {
          return 'Upload your ID to continue.';
        }
      case 6:
        if (!d.intentConfirmed) return 'Confirm that you are here for marriage.';
        if (!d.dataConsent) return 'Agree to how your details are used.';
    }
    return null;
  }

  Future<void> _next() async {
    if (_busy) return;
    final WardProfile typed = _withTyped();
    final String? problem = _problem(typed);
    setState(() => _error = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    final AppStore store = context.read<AppStore>();
    try {
      if (_step == OnboardingShell.totalSteps) {
        await store.saveDraft(typed);
        await store.submitProfile();
      } else {
        final WardProfile next = typed.copyWith(onboardingStep: _step + 1);
        await store.saveDraft(next);
        if (mounted) {
          setState(() {
            _d = next;
            _step++;
          });
        }
      }
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } on Object {
      if (mounted) showAppSnack(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _d = _withTyped();
      _error = null;
      _step--;
    });
  }

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime latest = DateTime(now.year - 18, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _d.dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: latest,
    );
    if (picked != null) _set(_d.copyWith(dateOfBirth: picked));
  }

  Future<void> _uploadAll(List<XFile> files) async {
    if (files.isEmpty || !mounted) return;
    final AppStore store = context.read<AppStore>();
    setState(() {
      _busy = true;
      _uploadProgress = 0;
    });
    try {
      final List<String> stored = <String>[];
      for (int i = 0; i < files.length; i++) {
        stored.add(await store.uploadPhoto(
          files[i].path,
          onProgress: (double p) {
            if (mounted) setState(() => _uploadProgress = (i + p) / files.length);
          },
        ));
      }
      _set(_d.copyWith(photos: <String>[..._d.photos, ...stored]));
      await store.saveDraft(_d);
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } on Object {
      if (mounted) showAppSnack(context, 'Upload failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _pickPhotos() async {
    final int room = _maxPhotos - _d.photos.length;
    if (room <= 0) return;
    final List<XFile> files = await ImagePicker().pickMultiImage(
      limit: room > 1 ? room : null,
      maxWidth: 1600,
      imageQuality: 85,
    );
    await _uploadAll(files.take(room).toList());
  }

  Future<void> _takePhoto() async {
    if (_d.photos.length >= _maxPhotos) return;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file != null) await _uploadAll(<XFile>[file]);
  }

  Future<void> _reorderPhotos(List<String> next) async {
    _set(_d.copyWith(photos: next));
    try {
      await context.read<AppStore>().saveDraft(_d);
    } on Object {
      if (mounted) showAppSnack(context, 'Could not save. Please try again.');
    }
  }

  Future<void> _removePhoto(String stored) async {
    final AppStore store = context.read<AppStore>();
    try {
      await store.removePhoto(stored);
      _set(_d.copyWith(photos: _d.photos.where((String p) => p != stored).toList()));
    } on Object {
      if (mounted) showAppSnack(context, 'Could not remove that photo.');
    }
  }

  Widget _label(String text, {bool required = false, int? count, int? max}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 12),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ts(11, FontWeight.w800, color: AppTheme.green, letterSpacing: 0.6),
            ),
          ),
          if (required)
            Text(' *', style: AppTheme.ts(12, FontWeight.w800, color: AppTheme.danger)),
          const Spacer(),
          if (max != null) Text('$count/$max', style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _picker({
    required Key key,
    required IconData icon,
    required String value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: AppTheme.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? hint : tr(value),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.ts(
                  14.5,
                  FontWeight.w600,
                  color: value.isEmpty ? AppTheme.slate400 : AppTheme.slate900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(String title, List<String> options, void Function(String) apply) async {
    final String? v = await showOptionSheet(context, title: title, options: options);
    if (v != null) apply(v);
  }

  Widget _whoStep() {
    Widget option(String value, IconData icon, String title, String body) {
      final bool on = _d.managedBy == value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          key: Key('who_$value'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _set(_d.copyWith(managedBy: value)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? AppTheme.green : AppTheme.slate200, width: on ? 1.6 : 1),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: AppTheme.green),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppTheme.ts(15.5, FontWeight.w800, color: AppTheme.slate900)),
                      const SizedBox(height: 2),
                      Text(body, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  on ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: on ? AppTheme.green : AppTheme.slate300,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        option('self', Icons.person_outline_rounded, tr('Myself'), tr('I am creating this profile for myself')),
        option('family', Icons.people_outline_rounded, tr('A family Member'), tr('I am helping a family member')),
        if (_d.managedBy == 'family')
          CheckboxListTile(
            key: const Key('candidate_consent'),
            contentPadding: EdgeInsets.zero,
            title: const Text('The person this profile is for has agreed to it and is 18 or older.'),
            value: _d.candidateConsent,
            onChanged: (bool? v) => _set(_d.copyWith(candidateConsent: v ?? false)),
          ),
      ],
    );
  }

  Widget _basicsStep() {
    final DateTime? dob = _d.dateOfBirth;
    final String home = <String>[_d.city, _d.homeState]
        .where((String s) => s.isNotEmpty)
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(tr('Full name'), required: true, count: _name.text.length, max: 20),
        TextField(
          key: const Key('full_name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(20)],
          decoration: InputDecoration(hintText: tr('Enter your full name')),
          onChanged: (_) => setState(() {}),
        ),
        _label(tr('Gender'), required: true),
        _picker(
          key: const Key('pick_gender'),
          icon: Icons.wc_rounded,
          value: _d.hasGender ? _d.gender.title : '',
          hint: tr('Select your gender'),
          onTap: () => _choose(tr('Select gender'), <String>['Male', 'Female'], (String v) {
            _set(_d.copyWith(
              hasGender: true,
              gender: v == 'Male' ? Gender.male : Gender.female,
            ));
          }),
        ),
        _label(tr('Date of birth'), required: true),
        _picker(
          key: const Key('pick_dob'),
          icon: Icons.calendar_month_outlined,
          value: dob == null ? '' : '${dob.day}/${dob.month}/${dob.year}',
          hint: tr('Select your date of birth'),
          onTap: _pickDob,
        ),
        _label(tr('Marital status'), required: true),
        _picker(
          key: const Key('pick_marital'),
          icon: Icons.favorite_border_rounded,
          value: _d.maritalStatus,
          hint: tr('Select marital status'),
          onTap: () => _choose('Marital Status', OptionLists.maritalStatus,
              (String v) => _set(_d.copyWith(maritalStatus: v))),
        ),
        _label(tr('Marriage readiness'), required: true),
        _picker(
          key: const Key('pick_readiness'),
          icon: Icons.schedule_rounded,
          value: _d.marriageReadiness,
          hint: tr('Select marriage readiness'),
          onTap: () => _choose(tr('Marriage readiness'), OptionLists.marriageReadiness,
              (String v) => _set(_d.copyWith(marriageReadiness: v))),
        ),
        if (_d.maritalStatus.isNotEmpty &&
            _d.maritalStatus != OptionLists.maritalStatus.first) ...<Widget>[
          _label(tr('Children'), required: true),
          _picker(
            key: const Key('pick_children'),
            icon: Icons.child_care_rounded,
            value: _d.children,
            hint: tr('Select'),
            onTap: () => _choose(tr('Children'), OptionLists.children,
                (String v) => _set(_d.copyWith(children: v))),
          ),
        ],
        _label(tr('Home city'), required: true),
        _picker(
          key: const Key('pick_home'),
          icon: Icons.home_outlined,
          value: home,
          hint: tr('Choose home city'),
          onTap: () async {
            final PickedLocation? p = await showLocationSheet(
              context,
              title: 'Your home city',
              initial: PickedLocation(_d.country, _d.homeState, _d.city),
            );
            if (p != null) {
              _set(_d.copyWith(country: p.country, homeState: p.region, city: p.city));
            }
          },
        ),
        _label(tr('Preferred language')),
        _picker(
          key: const Key('pick_language'),
          icon: Icons.translate_rounded,
          value: _d.preferredLanguage,
          hint: tr('Select language'),
          onTap: () => _choose(tr('Preferred language'), OptionLists.languages,
              (String v) => _set(_d.copyWith(preferredLanguage: v))),
        ),
        _label(tr('Phone number'), required: true),
        _phoneRow(),
      ],
    );
  }

  Widget _phoneRow() {
    final String phone = context.watch<AppStore>().verifiedPhone;
    if (phone.isNotEmpty) {
      return ListTile(
        key: const Key('phone_verified'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.verified_rounded, color: AppTheme.green),
        title: Text(phone),
        subtitle: Text(tr('Verified. Never shown without your consent.')),
      );
    }
    return ListTile(
      key: const Key('verify_phone'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.phone_iphone_rounded, color: AppTheme.goldDeep),
      title: Text(tr('Verify your phone number')),
      subtitle: Text(tr('Needed before you can submit your profile.')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.verifyPhone),
    );
  }

  Widget _workCity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(tr('Work city')),
        if (!_d.workSameAsHome)
          _picker(
            key: const Key('pick_work'),
            icon: Icons.work_outline_rounded,
            value: _d.workCity,
            hint: tr('Current city'),
            onTap: () async {
              final PickedLocation? p =
                  await showLocationSheet(context, title: 'Your current city');
              if (p != null) _set(_d.copyWith(workCity: p.city));
            },
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Same as home city')),
          subtitle: Text(tr('Turn off if you live or work in a different city.')),
          value: _d.workSameAsHome,
          onChanged: (bool v) => _set(_d.copyWith(workSameAsHome: v)),
        ),
      ],
    );
  }

  Widget _text(
    String key,
    String label,
    String hint,
    TextEditingController controller, {
    int lines = 1,
    int max = 300,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(label),
        TextField(
          key: Key(key),
          controller: controller,
          maxLines: lines,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(max)],
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _personalFamilyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(tr('Who is looking for a Nikah match?'),
            style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 10),
        _whoStep(),
        _label(tr('Height'), required: true),
        _picker(
          key: const Key('pick_height'),
          icon: Icons.height_rounded,
          value: _d.height,
          hint: tr('Select your height'),
          onTap: () => _choose(tr('Height'), OptionLists.heights,
              (String v) => _set(_d.copyWith(height: v))),
        ),
        _text('about_me', tr('About you'), tr('A few lines in your own words'), _about, lines: 3, max: 1000),
        _label(tr('Caste (optional)')),
        _picker(
          key: const Key('pick_caste'),
          icon: Icons.people_outline_rounded,
          value: _d.caste,
          hint: tr('Select caste'),
          onTap: () => _choose('Caste', OptionLists.castes,
              (String v) => _set(_d.copyWith(caste: v))),
        ),
        if (_d.caste.isNotEmpty && _d.caste != OptionLists.noCaste)
          SwitchListTile(
            key: const Key('show_caste'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Show caste on my profile')),
            value: _d.showCaste,
            onChanged: (bool v) => _set(_d.copyWith(showCaste: v)),
          ),
        _label(tr('Sect (optional)')),
        _picker(
          key: const Key('pick_sect'),
          icon: Icons.mosque_outlined,
          value: _d.sect,
          hint: tr('Select sect'),
          onTap: () => _choose('Sect', OptionLists.sects,
              (String v) => _set(_d.copyWith(sect: v))),
        ),
        _label(tr('Partner caste')),
        _picker(
          key: const Key('pick_partner_caste'),
          icon: Icons.favorite_border_rounded,
          value: _d.partnerCaste,
          hint: tr('No preference'),
          onTap: () => _choose(tr('Partner caste'), OptionLists.castes,
              (String v) => _set(_d.copyWith(partnerCaste: v))),
        ),
        const SizedBox(height: 18),
        Text(tr('Your family'), style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
        Text(tr('Optional. Shared only with people you match with.'), style: AppTheme.bodySmall),
        _label(tr('Family type')),
        _picker(
          key: const Key('pick_family_type'),
          icon: Icons.home_work_outlined,
          value: _d.familyType,
          hint: tr('Select'),
          onTap: () => _choose(tr('Family type'), OptionLists.familyTypes,
              (String v) => _set(_d.copyWith(familyType: v))),
        ),
        _label(tr('Family values')),
        _picker(
          key: const Key('pick_family_values'),
          icon: Icons.volunteer_activism_outlined,
          value: _d.familyValues,
          hint: tr('Select'),
          onTap: () => _choose(tr('Family values'), OptionLists.familyValues,
              (String v) => _set(_d.copyWith(familyValues: v))),
        ),
        _label(tr('Siblings')),
        _picker(
          key: const Key('pick_siblings'),
          icon: Icons.groups_outlined,
          value: _d.siblings,
          hint: tr('Select'),
          onTap: () => _choose(tr('Siblings'), OptionLists.siblingCounts,
              (String v) => _set(_d.copyWith(siblings: v))),
        ),
        _text('family_location', tr('Family location'), tr('City or town'), _familyLocation, max: 100),
        _text('family_background', tr('Family background'), tr('A short summary'), _familyBackground, lines: 3, max: 800),
      ],
    );
  }

  Widget _educationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(tr('Alma mater'), required: true),
        _picker(
          key: const Key('pick_alma'),
          icon: Icons.account_balance_outlined,
          value: _d.almaMaters.join(', '),
          hint: tr('Select Alma Mater'),
          onTap: () async {
            final List<String>? v =
                await showAlmaMaterSheet(context, selected: _d.almaMaters);
            if (v != null) _set(_d.copyWith(almaMaters: v));
          },
        ),
        _label(tr('Education (completed / pursuing)'), required: true),
        _picker(
          key: const Key('pick_qualification'),
          icon: Icons.school_outlined,
          value: _d.qualification,
          hint: tr('Select qualification'),
          onTap: () => _choose('Qualification', OptionLists.qualifications.keys.toList(),
              (String v) => _set(_d.copyWith(qualification: v))),
        ),
        _label(tr('Education status')),
        _picker(
          key: const Key('pick_education_status'),
          icon: Icons.history_edu_outlined,
          value: _d.educationStatus,
          hint: tr('Select'),
          onTap: () => _choose(tr('Education status'), OptionLists.educationStatuses,
              (String v) => _set(_d.copyWith(educationStatus: v))),
        ),
        _label(tr('Graduation year')),
        _picker(
          key: const Key('pick_graduation_year'),
          icon: Icons.event_outlined,
          value: _d.graduationYear,
          hint: tr('Select'),
          onTap: () => _choose(
            tr('Graduation year'),
            <String>[for (int y = DateTime.now().year + 6; y >= 1970; y--) '$y'],
            (String v) => _set(_d.copyWith(graduationYear: v)),
          ),
        ),
        if (OptionLists.qualifications[_d.qualification] == false) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            tr('This community is for graduates and degree students.'),
            style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.danger),
          ),
        ],
        _label(tr('Profession'), required: true),
        _picker(
          key: const Key('pick_profession'),
          icon: Icons.work_outline_rounded,
          value: _d.profession,
          hint: tr('Select profession'),
          onTap: () => _choose(tr('Profession'), OptionLists.professions,
              (String v) => _set(_d.copyWith(profession: v))),
        ),
        _label(tr('Employment status')),
        _picker(
          key: const Key('pick_employment'),
          icon: Icons.badge_outlined,
          value: _d.employmentStatus,
          hint: tr('Select'),
          onTap: () => _choose(tr('Employment status'), OptionLists.employmentStatuses,
              (String v) => _set(_d.copyWith(employmentStatus: v))),
        ),
        _label(tr('Income range')),
        _picker(
          key: const Key('pick_income'),
          icon: Icons.currency_rupee_rounded,
          value: _d.incomeRange,
          hint: tr('Select'),
          onTap: () => _choose(tr('Income range'), OptionLists.incomeRanges,
              (String v) => _set(_d.copyWith(incomeRange: v))),
        ),
        _label(tr('Company / business name'), count: _company.text.length, max: 40),
        TextField(
          key: const Key('company'),
          controller: _company,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(40)],
          decoration: InputDecoration(hintText: tr('Employer, business, or institution')),
          onChanged: (_) => setState(() {}),
        ),
        _workCity(),
        _text('career', tr('About your work'), tr('A few lines about your career'), _career, lines: 3, max: 800),
      ],
    );
  }

  Widget _photoStep() {
    Widget avoid(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.close_rounded, size: 15, color: AppTheme.danger),
              const SizedBox(width: 10),
              Flexible(
                child: Text(text, style: AppTheme.ts(14, FontWeight.w600, color: AppTheme.slate600)),
              ),
            ],
          ),
        );
    return Column(
      children: <Widget>[
        if (_d.photos.isNotEmpty || _uploadProgress != null)
          PhotoManager(
            photos: _d.photos,
            rejected: context.watch<AppStore>().rejectedPhotos,
            progress: _uploadProgress,
            onRemove: _removePhoto,
            onReorder: _reorderPhotos,
          ),
        if (_d.photos.isNotEmpty && _d.photos.length < _maxPhotos)
          TextButton.icon(
            key: const Key('add_more_photos'),
            onPressed: _busy ? null : _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr('Add more photos')),
          ),
        TextButton.icon(
          key: const Key('take_photo'),
          onPressed: _busy ? null : _takePhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(tr('Take a photo')),
        ),
        SwitchListTile(
          key: const Key('photos_after_match'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Show my photos only after we match')),
          subtitle: Text(tr('Others see your details, but not your face, until you match.')),
          value: _d.photoPrivacy == 'matches',
          onChanged: (bool v) =>
              _set(_d.copyWith(photoPrivacy: v ? 'matches' : 'everyone')),
        ),
        const SizedBox(height: 18),
        Text(tr('PLEASE AVOID'), style: AppTheme.ts(11.5, FontWeight.w800, color: AppTheme.slate400)),
        const SizedBox(height: 10),
        avoid(tr('AI-edited or filtered photos')),
        avoid(tr('Blurry or dark photos')),
        avoid(tr('Group photos')),
        const SizedBox(height: 16),
        Text(tr('Who sees your photos'),
            style: AppTheme.ts(13.5, FontWeight.w800, color: AppTheme.green)),
        Text(
          tr('Only reviewed photos are shown. We block screenshots where the phone allows it, but no app can prevent every copy.'),
          style: AppTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _verificationStep() {
    final AppStore store = context.watch<AppStore>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          store.requireIdProof
              ? tr('Your ID is needed to go live. Our team reviews it and it is never shown to members.')
              : tr('Upload documents to earn the verified badge.'),
          style: AppTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        for (final VerificationDoc doc in store.verificationDocs)
          ListTile(
            key: Key('step_doc_${doc.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(doc.title),
            subtitle: Text(doc.rejectionReason.isEmpty
                ? doc.status.label
                : '${doc.status.label}: ${doc.rejectionReason}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.verifyProfile),
          ),
        const SizedBox(height: 10),
        Text(
          tr('A badge means our team reviewed the evidence you sent. It is not a background check or a guarantee.'),
          style: AppTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _reviewStep() {
    Widget row(String k, String v) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 110, child: Text(k, style: AppTheme.bodySmall)),
                Expanded(
                  child: Text(v, style: AppTheme.ts(13.5, FontWeight.w600, color: AppTheme.slate900)),
                ),
              ],
            ),
          );
    Widget section(String title, int step, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(title, style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
                  ),
                  TextButton(
                    key: Key('edit_step_$step'),
                    onPressed: () => setState(() => _step = step),
                    child: Text(tr('Edit')),
                  ),
                ],
              ),
              ...rows,
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        section(tr('Basic information'), 1, <Widget>[
          row('Name', _d.displayName),
          row('Status', tr(_d.maritalStatus)),
          row('Readiness', tr(_d.marriageReadiness)),
          row('Home', <String>[_d.city, _d.homeState, _d.country].where((String s) => s.isNotEmpty).join(', ')),
        ]),
        section(tr('Personal and family'), 2, <Widget>[
          row('Managed by', _d.managedBy == 'family' ? tr('A family Member') : tr('Myself')),
          row('Caste', _d.caste),
          row(tr('Height'), _d.height),
          row(tr('Family type'), _d.familyType),
          row(tr('Family location'), _d.familyLocation),
        ]),
        section(tr('Education & profession'), 3, <Widget>[
          row(tr('Alma mater'), _d.almaMaters.join(', ')),
          row('Education', _d.qualification),
          row(tr('Profession'), <String>[_d.profession, _d.company].where((String s) => s.isNotEmpty).join(', ')),
        ]),
        section(tr('Photos'), 4, <Widget>[
          row('Photos', '${_d.photos.length}'),
          row(
            tr('Who sees them'),
            _d.photoPrivacy == 'matches' ? tr('Only people you match with') : tr('Members who see your profile'),
          ),
        ]),
        ListTile(
          key: const Key('add_deen'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Deen and values (optional)')),
          subtitle: Text(tr('Prayer, Quran and lifestyle')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final AppStore s = context.read<AppStore>();
            await s.saveDraft(_withTyped());
            if (!mounted) return;
            await context.push(AppRoutes.practice);
            if (mounted && s.profile != null) _set(s.profile!);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('invite_code_input'),
          controller: _invite,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: tr('Invite code (optional)'),
            counterText: '',
          ),
        ),
        CheckboxListTile(
          key: const Key('confirm_intent'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr('I am here for marriage, and my details are true.')),
          value: _d.intentConfirmed,
          onChanged: (bool? v) => _set(_d.copyWith(intentConfirmed: v ?? false)),
        ),
        CheckboxListTile(
          key: const Key('confirm_consent'),
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I agree that my details, photos and documents are used for review and matching, '
            'as described in the Privacy Policy.',
          ),
          value: _d.dataConsent,
          onChanged: (bool? v) => _set(_d.copyWith(dataConsent: v ?? false)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (String title, String? subtitle, Widget body) = switch (_step) {
      1 => (tr('Basic information'), null, _basicsStep()),
      2 => (tr('Personal and family'), null, _personalFamilyStep()),
      3 => (tr('Education & profession'), null, _educationStep()),
      4 => (tr('Add your photos'), 'A clear photo helps your profile get noticed.', _photoStep()),
      5 => (tr('Verification'), null, _verificationStep()),
      _ => (tr('Review and submit'), 'Our team reviews every profile before it goes live.', _reviewStep()),
    };
    final bool needsPhotos = _step == 4 && _d.photos.isEmpty;
    return OnboardingShell(
      step: _step,
      title: title,
      subtitle: subtitle,
      onBack: _step > 1 ? _back : null,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                key: const Key('onboarding_error'),
                textAlign: TextAlign.center,
                style: AppTheme.ts(13, FontWeight.w600, color: AppTheme.danger),
              ),
            ),
          PrimaryButton(
            key: const Key('onboarding_next'),
            label: _busy
                ? tr('Please wait…')
                : needsPhotos
                    ? tr('Add photos')
                    : _step == OnboardingShell.totalSteps
                        ? tr('Submit for review')
                        : tr('Next'),
            icon: needsPhotos ? Icons.add_photo_alternate_outlined : Icons.arrow_forward_rounded,
            progress: _busy,
            onPressed: _busy ? null : (needsPhotos ? _pickPhotos : _next),
          ),
        ],
      ),
      child: body,
    );
  }
}

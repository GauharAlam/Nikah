import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
import '../../widgets/picker_sheets.dart';

/// The seven profile steps. Each Next saves the draft, so a member resumes
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
  late final TextEditingController _phone;
  late final TextEditingController _company;

  @override
  void initState() {
    super.initState();
    _d = context.read<AppStore>().profile ?? const WardProfile(phoneCode: '+91');
    _step = _d.onboardingStep.clamp(1, OnboardingShell.totalSteps);
    _name = TextEditingController(text: _d.displayName);
    _phone = TextEditingController(text: _d.phone);
    _company = TextEditingController(text: _d.company);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  void _set(WardProfile next) => setState(() {
        _d = next;
        _error = null;
      });

  WardProfile _withTyped() => _d.copyWith(
        displayName: _name.text.trim(),
        phone: _phone.text.trim(),
        company: _company.text.trim(),
      );

  /// What stops the current step being completed, if anything.
  String? _problem(WardProfile d) {
    switch (_step) {
      case 1:
        if (d.managedBy == 'family' && !d.candidateConsent) {
          return 'Confirm that the person has agreed to this profile.';
        }
      case 2:
        if (d.displayName.length < 2) return 'Enter your full name.';
        if (!d.hasGender) return 'Select your gender.';
        if (d.maritalStatus.isEmpty) return 'Select your marital status.';
        if (d.marriageReadiness.isEmpty) return 'Select your marriage readiness.';
        if (d.maritalStatus != OptionLists.maritalStatus.first && d.children.isEmpty) {
          return 'Tell us about children.';
        }
      case 3:
        if (d.city.isEmpty) return 'Choose your home city.';
        if (!d.workSameAsHome && d.workCity.isEmpty) return 'Choose your current city.';
      case 4:
        if (d.dateOfBirth == null) return 'Select your date of birth.';
        if ((d.age ?? 0) < 18) return 'You must be at least 18.';
        if (d.height.isEmpty) return 'Select your height.';
        final int digits = d.phone.length;
        if (d.phoneCode == '+91' ? digits != 10 : digits < 7 || digits > 13) {
          return 'Enter a valid contact number.';
        }
      case 5:
        if (d.almaMaters.isEmpty) return 'Select your alma mater.';
        if (d.qualification.isEmpty) return 'Select your qualification.';
        if (context.read<AppStore>().graduatesOnly &&
            OptionLists.qualifications[d.qualification] == false) {
          return 'This community is for graduates and degree students.';
        }
        if (d.profession.isEmpty) return 'Select your profession.';
      case 6:
        if (d.photos.isEmpty) return 'Add at least one photo.';
      case 7:
        final AppStore store = context.read<AppStore>();
        final VerificationDoc id = store.verificationDocs
            .firstWhere((VerificationDoc x) => x.id == 'name-proof');
        if (store.requireIdProof &&
            (id.status == VerificationDocStatus.missing ||
                id.status == VerificationDocStatus.rejected)) {
          return 'Upload your ID to submit your profile.';
        }
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

  Future<void> _pickPhotos() async {
    final int room = _maxPhotos - _d.photos.length;
    if (room <= 0) return;
    final AppStore store = context.read<AppStore>();
    final List<XFile> files = await ImagePicker().pickMultiImage(
      limit: room > 1 ? room : null,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final List<String> stored = <String>[];
      for (final XFile f in files.take(room)) {
        stored.add(await store.uploadPhoto(f.path));
      }
      _set(_d.copyWith(photos: <String>[..._d.photos, ...stored]));
      await store.saveDraft(_d);
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } on Object {
      if (mounted) showAppSnack(context, 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
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
                value.isEmpty ? hint : value,
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
        option('self', Icons.person_outline_rounded, 'Myself', 'I am creating this profile for myself'),
        option('family', Icons.people_outline_rounded, 'A family Member', 'I am helping a family member'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label('Full name', required: true, count: _name.text.length, max: 20),
        TextField(
          key: const Key('full_name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(20)],
          decoration: const InputDecoration(hintText: 'Enter your full name'),
          onChanged: (_) => setState(() {}),
        ),
        _label('Gender', required: true),
        _picker(
          key: const Key('pick_gender'),
          icon: Icons.wc_rounded,
          value: _d.hasGender ? _d.gender.title : '',
          hint: 'Select your gender',
          onTap: () => _choose('Select gender', <String>['Male', 'Female'], (String v) {
            _set(_d.copyWith(
              hasGender: true,
              gender: v == 'Male' ? Gender.male : Gender.female,
            ));
          }),
        ),
        _label('Marital status', required: true),
        _picker(
          key: const Key('pick_marital'),
          icon: Icons.favorite_border_rounded,
          value: _d.maritalStatus,
          hint: 'Select marital status',
          onTap: () => _choose('Marital Status', OptionLists.maritalStatus,
              (String v) => _set(_d.copyWith(maritalStatus: v))),
        ),
        _label('Marriage readiness', required: true),
        _picker(
          key: const Key('pick_readiness'),
          icon: Icons.schedule_rounded,
          value: _d.marriageReadiness,
          hint: 'Select marriage readiness',
          onTap: () => _choose('Marriage readiness', OptionLists.marriageReadiness,
              (String v) => _set(_d.copyWith(marriageReadiness: v))),
        ),
        if (_d.maritalStatus.isNotEmpty &&
            _d.maritalStatus != OptionLists.maritalStatus.first) ...<Widget>[
          _label('Children', required: true),
          _picker(
            key: const Key('pick_children'),
            icon: Icons.child_care_rounded,
            value: _d.children,
            hint: 'Select',
            onTap: () => _choose('Children', OptionLists.children,
                (String v) => _set(_d.copyWith(children: v))),
          ),
        ],
      ],
    );
  }

  Widget _citiesStep() {
    final String home = <String>[_d.city, _d.homeState]
        .where((String s) => s.isNotEmpty)
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label('Home city', required: true),
        _picker(
          key: const Key('pick_home'),
          icon: Icons.home_outlined,
          value: home,
          hint: 'Choose home city',
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
        _label('Work city'),
        if (!_d.workSameAsHome)
          _picker(
            key: const Key('pick_work'),
            icon: Icons.work_outline_rounded,
            value: _d.workCity,
            hint: 'Current city',
            onTap: () async {
              final PickedLocation? p =
                  await showLocationSheet(context, title: 'Your current city');
              if (p != null) _set(_d.copyWith(workCity: p.city));
            },
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Same as home city'),
          subtitle: const Text('Turn off if you live or work in a different city.'),
          value: _d.workSameAsHome,
          onChanged: (bool v) => _set(_d.copyWith(workSameAsHome: v)),
        ),
      ],
    );
  }

  Widget _personalStep() {
    final DateTime? dob = _d.dateOfBirth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label('Date of birth', required: true),
        _picker(
          key: const Key('pick_dob'),
          icon: Icons.calendar_month_outlined,
          value: dob == null ? '' : '${dob.day}/${dob.month}/${dob.year}',
          hint: 'Select your date of birth',
          onTap: _pickDob,
        ),
        _label('Caste (optional)'),
        _picker(
          key: const Key('pick_caste'),
          icon: Icons.people_outline_rounded,
          value: _d.caste,
          hint: 'Select caste',
          onTap: () => _choose('Caste', OptionLists.castes,
              (String v) => _set(_d.copyWith(caste: v))),
        ),
        if (_d.caste.isNotEmpty && _d.caste != OptionLists.noCaste)
          SwitchListTile(
            key: const Key('show_caste'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show caste on my profile'),
            value: _d.showCaste,
            onChanged: (bool v) => _set(_d.copyWith(showCaste: v)),
          ),
        _label('Sect (optional)'),
        _picker(
          key: const Key('pick_sect'),
          icon: Icons.mosque_outlined,
          value: _d.sect,
          hint: 'Select sect',
          onTap: () => _choose('Sect', OptionLists.sects,
              (String v) => _set(_d.copyWith(sect: v))),
        ),
        _label('Partner caste'),
        _picker(
          key: const Key('pick_partner_caste'),
          icon: Icons.favorite_border_rounded,
          value: _d.partnerCaste,
          hint: 'No preference',
          onTap: () => _choose('Partner caste', OptionLists.castes,
              (String v) => _set(_d.copyWith(partnerCaste: v))),
        ),
        _label('Height', required: true),
        _picker(
          key: const Key('pick_height'),
          icon: Icons.height_rounded,
          value: _d.height,
          hint: 'Select your height',
          onTap: () => _choose('Height', OptionLists.heights,
              (String v) => _set(_d.copyWith(height: v))),
        ),
        _label('Contact number', required: true),
        Row(
          children: <Widget>[
            DropdownButton<String>(
              value: OptionLists.countryCodes.containsKey(_d.phoneCode) ? _d.phoneCode : '+91',
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<String>>[
                for (final String code in OptionLists.countryCodes.keys)
                  DropdownMenuItem<String>(value: code, child: Text(code)),
              ],
              onChanged: (String? v) => _set(_d.copyWith(phoneCode: v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('contact_number'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: const InputDecoration(hintText: 'Mobile number'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Your contact will never be shared without your consent.',
            style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _educationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label('Alma mater', required: true),
        _picker(
          key: const Key('pick_alma'),
          icon: Icons.account_balance_outlined,
          value: _d.almaMaters.join(', '),
          hint: 'Select Alma Mater',
          onTap: () async {
            final List<String>? v =
                await showAlmaMaterSheet(context, selected: _d.almaMaters);
            if (v != null) _set(_d.copyWith(almaMaters: v));
          },
        ),
        _label('Education (completed / pursuing)', required: true),
        _picker(
          key: const Key('pick_qualification'),
          icon: Icons.school_outlined,
          value: _d.qualification,
          hint: 'Select qualification',
          onTap: () => _choose('Qualification', OptionLists.qualifications.keys.toList(),
              (String v) => _set(_d.copyWith(qualification: v))),
        ),
        if (OptionLists.qualifications[_d.qualification] == false) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'This community is for graduates and degree students.',
            style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.danger),
          ),
        ],
        _label('Profession', required: true),
        _picker(
          key: const Key('pick_profession'),
          icon: Icons.work_outline_rounded,
          value: _d.profession,
          hint: 'Select profession',
          onTap: () => _choose('Profession', OptionLists.professions,
              (String v) => _set(_d.copyWith(profession: v))),
        ),
        _label('Income range'),
        _picker(
          key: const Key('pick_income'),
          icon: Icons.currency_rupee_rounded,
          value: _d.incomeRange,
          hint: 'Select',
          onTap: () => _choose('Income range', OptionLists.incomeRanges,
              (String v) => _set(_d.copyWith(incomeRange: v))),
        ),
        _label('Company / business name', count: _company.text.length, max: 40),
        TextField(
          key: const Key('company'),
          controller: _company,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(40)],
          decoration: const InputDecoration(hintText: 'Employer, business, or institution'),
          onChanged: (_) => setState(() {}),
        ),
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
        if (_d.photos.isNotEmpty)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: <Widget>[
              for (final String p in _d.photos)
                _PhotoTile(stored: p, onRemove: () => _removePhoto(p)),
            ],
          ),
        SwitchListTile(
          key: const Key('photos_after_match'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Show my photos only after we match'),
          subtitle: const Text('Others see your details, but not your face, until you match.'),
          value: _d.photoPrivacy == 'matches',
          onChanged: (bool v) =>
              _set(_d.copyWith(photoPrivacy: v ? 'matches' : 'everyone')),
        ),
        const SizedBox(height: 18),
        Text('PLEASE AVOID', style: AppTheme.ts(11.5, FontWeight.w800, color: AppTheme.slate400)),
        const SizedBox(height: 10),
        avoid('AI-edited or filtered photos'),
        avoid('Blurry or dark photos'),
        avoid('Group photos'),
        const SizedBox(height: 16),
        Text('Screenshots are not allowed',
            style: AppTheme.ts(13.5, FontWeight.w800, color: AppTheme.green)),
        Text('Your pictures stay private and safe', style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _reviewStep() {
    final AppStore store = context.watch<AppStore>();
    Widget row(String k, String v) => Padding(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row('Name', _d.displayName),
        row('Status', _d.maritalStatus),
        row('Readiness', _d.marriageReadiness),
        row('Home', <String>[_d.city, _d.homeState, _d.country].where((String s) => s.isNotEmpty).join(', ')),
        row('Caste', _d.caste),
        row('Height', _d.height),
        row('Alma mater', _d.almaMaters.join(', ')),
        row('Education', _d.qualification),
        row('Profession', <String>[_d.profession, _d.company].where((String s) => s.isNotEmpty).join(', ')),
        row('Photos', '${_d.photos.length}'),
        ListTile(
          key: const Key('add_deen'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Deen and values (optional)'),
          subtitle: const Text('Prayer, Quran and lifestyle'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final AppStore s = context.read<AppStore>();
            await s.saveDraft(_withTyped());
            if (!mounted) return;
            await context.push(AppRoutes.practice);
            if (mounted && s.profile != null) _set(s.profile!);
          },
        ),
        const SizedBox(height: 14),
        Text('Verification',
            style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        Text(
          store.requireIdProof
              ? 'Your ID is needed to go live. Our team reviews it and it is never shown to members.'
              : 'Upload documents to earn the verified badge.',
          style: AppTheme.bodySmall,
        ),
        for (final VerificationDoc doc in store.verificationDocs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(doc.title),
            subtitle: Text(doc.status.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.verifyProfile),
          ),
        CheckboxListTile(
          key: const Key('confirm_intent'),
          contentPadding: EdgeInsets.zero,
          title: const Text('I am here for marriage, and my details are true.'),
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
      1 => ('Who is looking for a Nikah match?', null, _whoStep()),
      2 => ('Let\'s start with the basics', null, _basicsStep()),
      3 => ('Choose your cities of residence & work', null, _citiesStep()),
      4 => ('Personal details', null, _personalStep()),
      5 => ('Education & profession', null, _educationStep()),
      6 => ('Add your photos', 'A clear photo helps your profile get noticed.', _photoStep()),
      _ => ('Review and submit', 'Our team reviews every profile before it goes live.', _reviewStep()),
    };
    final bool needsPhotos = _step == 6 && _d.photos.isEmpty;
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
                ? 'Please wait…'
                : needsPhotos
                    ? 'Add photos'
                    : _step == OnboardingShell.totalSteps
                        ? 'Submit for review'
                        : 'Next',
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.stored, required this.onRemove});

  final String stored;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<String>(
            future: context.read<AppStore>().photoSource(stored),
            builder: (_, AsyncSnapshot<String> snap) {
              final String? src = snap.data;
              if (src == null) return const ColoredBox(color: AppTheme.slate200);
              if (src.startsWith('http')) return Image.network(src, fit: BoxFit.cover);
              if (kIsWeb) return const ColoredBox(color: AppTheme.slate200);
              return Image.file(File(src), fit: BoxFit.cover);
            },
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filledTonal(
            tooltip: 'Remove photo',
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

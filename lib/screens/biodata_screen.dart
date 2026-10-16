import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';
import '../widgets/app_switch.dart';
import '../widgets/app_buttons.dart';
import '../widgets/onboarding_shell.dart';

/// Onboarding step 4 — the biodata builder that completes the ward's
/// profile before guardian review.
class BiodataStepScreen extends StatefulWidget {
  const BiodataStepScreen({super.key});

  @override
  State<BiodataStepScreen> createState() => _BiodataStepScreenState();
}

class _BiodataStepScreenState extends State<BiodataStepScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _education;
  late final TextEditingController _profession;
  late final TextEditingController _aboutMe;

  bool _blurPhotos = true;
  bool _shareWithWaliOnly = true;

  @override
  void initState() {
    super.initState();
    final WardProfile base =
        context.read<AppStore>().profile ?? WardProfile.demoWard;
    _city = TextEditingController(
      text: base.city.isEmpty ? 'London' : base.city,
    );
    _country = TextEditingController(
      text: base.country.isEmpty ? 'United Kingdom' : base.country,
    );
    _education = TextEditingController(
      text: base.education.isEmpty
          ? 'Pharmacy — King\'s College London'
          : base.education,
    );
    _profession = TextEditingController(
      text: base.profession.isEmpty ? 'Community Pharmacist' : base.profession,
    );
    _aboutMe = TextEditingController(
      text: base.aboutMe.isEmpty
          ? 'Assalamu alaikum. I am a community pharmacist in London who '
              'values faith-first living, family gatherings and serving the '
              'ummah. Seeking a tranquil home built on sabr, shukr and mutual '
              'respect, in sha Allah.'
          : base.aboutMe,
    );
    final AppStore store = context.read<AppStore>();
    _blurPhotos = store.privacy('blurPhotos');
    _shareWithWaliOnly = store.privacy('shareWithWaliOnly');
    for (final TextEditingController c in <TextEditingController>[
      _city,
      _country,
      _education,
      _profession,
      _aboutMe,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _city,
      _country,
      _education,
      _profession,
      _aboutMe,
    ]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(
        context,
        'Please complete the highlighted fields.',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final AppStore store = context.read<AppStore>();
    store.updateProfile(
      (WardProfile p) => p.copyWith(
        city: _city.text.trim(),
        country: _country.text.trim(),
        education: _education.text.trim(),
        profession: _profession.text.trim(),
        aboutMe: _aboutMe.text.trim(),
      ),
    );
    if (store.privacy('blurPhotos') != _blurPhotos) {
      store.togglePrivacy('blurPhotos', _blurPhotos);
    }
    if (store.privacy('shareWithWaliOnly') != _shareWithWaliOnly) {
      store.togglePrivacy('shareWithWaliOnly', _shareWithWaliOnly);
    }
    store.markStepDone(6);
    showSuccessSnack(context, 'Biodata saved — one final review, in sha Allah.');
    context.push(AppRoutes.onboardingReview);
  }

  String get _initials {
    final String name =
        (context.read<AppStore>().profile?.displayName ?? '').trim();
    if (name.isEmpty) return 'A';
    final List<String> parts = name.split(RegExp(r'\s+'));
    return parts.take(2).map((String p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final WardProfile profile =
        context.watch<AppStore>().profile ?? WardProfile.demoWard;
    return OnboardingShell(
      step: 6,
      title: 'Complete Biodata',
      subtitle: 'This record is what your Wali and prospective families will '
          'review first.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionLabel('Location & background'),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'City',
                    controller: _city,
                    icon: Icons.location_city_outlined,
                    textInputAction: TextInputAction.next,
                    validator: (String? v) => (v ?? '').trim().isEmpty
                        ? 'City is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Country',
                    controller: _country,
                    icon: Icons.public_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Education',
              controller: _education,
              icon: Icons.school_outlined,
              textInputAction: TextInputAction.next,
              validator: (String? v) =>
                  (v ?? '').trim().length < 3 ? 'Education is required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Profession',
              controller: _profession,
              icon: Icons.work_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (String? v) =>
                  (v ?? '').trim().length < 3 ? 'Profession is required' : null,
            ),
            const SizedBox(height: 22),
            const SectionLabel('About me'),
            const SizedBox(height: 10),
            AppTextField(
              label: 'A short, sincere introduction',
              controller: _aboutMe,
              hint: 'Your deen, your home values, and what you seek…',
              minLines: 4,
              maxLines: 6,
              maxLength: 600,
              validator: (String? v) => (v ?? '').trim().length < 40
                  ? 'Please write at least 40 characters'
                  : null,
            ),
            const SizedBox(height: 22),
            const SectionLabel('Photo settings'),
            const SizedBox(height: 10),
            AppSwitchRow(
              title: 'Modesty blur on my photos',
              subtitle: 'Photos stay softly blurred for non-approved '
                  'members — configurable anytime.',
              value: _blurPhotos,
              onChanged: (bool v) => setState(() => _blurPhotos = v),
            ),
            AppSwitchRow(
              title: 'Share photos with Wali only',
              subtitle: 'Only your appointed guardian sees the unblurred set.',
              value: _shareWithWaliOnly,
              onChanged: (bool v) => setState(() => _shareWithWaliOnly = v),
            ),
            const SizedBox(height: 14),
            _BiodataPreview(
              initials: _initials,
              name: profile.displayName.isEmpty
                  ? 'Amina Al-Mansoor'
                  : profile.displayName,
              age: profile.age,
              city: _city.text.trim(),
              prayerLabel: profile.prayerFrequency.label,
            ),
            const SizedBox(height: 26),
            PrimaryButton(
              label: 'Review My Biodata',
              icon: Icons.fact_check_outlined,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live mini-preview of the ward card as fields change.
class _BiodataPreview extends StatelessWidget {
  const _BiodataPreview({
    required this.initials,
    required this.name,
    required this.age,
    required this.city,
    required this.prayerLabel,
  });

  final String initials;
  final String name;
  final int? age;
  final String city;
  final String prayerLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ivoryWarm.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(url: '', initials: initials, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: AppTheme.ts(14, FontWeight.w800,
                      color: AppTheme.slate900),
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    if (age != null) '$age yrs',
                    if (city.isNotEmpty) city,
                    prayerLabel,
                  ].join(' · '),
                  style: AppTheme.ts(12, FontWeight.w600,
                      color: AppTheme.slate500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.visibility_outlined,
              size: 17, color: AppTheme.goldAccent),
        ],
      ),
    );
  }
}

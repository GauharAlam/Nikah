import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_snacks.dart';

/// Edit the ward's biodata inline; saves back through [AppStore] with a
/// dirty-state save control in the app bar.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _city;
  late final TextEditingController _education;
  late final TextEditingController _profession;
  late final TextEditingController _aboutMe;

  String _phoneCode = '+44';
  String _country = 'United Kingdom';
  String _relocation = 'Open to discuss';
  bool _dirty = false;

  static const List<String> _countries = <String>[
    'United Kingdom',
    'Pakistan',
    'United Arab Emirates',
    'Canada',
  ];

  static const List<String> _relocations = <String>[
    'Open to discuss',
    'Ready to relocate',
    'Staying in my city',
  ];

  @override
  void initState() {
    super.initState();
    final WardProfile base =
        context.read<AppStore>().profile ?? WardProfile.demoWard;
    _name = TextEditingController(text: base.displayName);
    _phone = TextEditingController(text: base.phone);
    _email = TextEditingController(text: base.email);
    _city = TextEditingController(text: base.city);
    _education = TextEditingController(text: base.education);
    _profession = TextEditingController(text: base.profession);
    _aboutMe = TextEditingController(text: base.aboutMe);
    _phoneCode = base.phoneCode;
    _country = _countries.contains(base.country) ? base.country : _countries.first;
    _relocation =
        _relocations.contains(base.relocation) ? base.relocation : _relocations.first;
    for (final TextEditingController c in _controllers) {
      c.addListener(_markDirty);
    }
  }

  List<TextEditingController> get _controllers => <TextEditingController>[
    _name,
    _phone,
    _email,
    _city,
    _education,
    _profession,
    _aboutMe,
  ];

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.removeListener(_markDirty);
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please review the highlighted fields.',
          icon: Icons.warning_amber_rounded);
      return;
    }
    context.read<AppStore>().updateProfile(
          (WardProfile p) => p.copyWith(
            displayName: _name.text.trim(),
            phoneCode: _phoneCode,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            city: _city.text.trim(),
            country: _country,
            education: _education.text.trim(),
            profession: _profession.text.trim(),
            aboutMe: _aboutMe.text.trim(),
            relocation: _relocation,
          ),
        );
    showSuccessSnack(context, 'Biodata updated, barakallahu feek.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Edit Biodata'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save changes',
            onPressed: _dirty ? _save : null,
            icon: Icon(
              Icons.save_outlined,
              color: _dirty ? AppTheme.green : AppTheme.slate300,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: <Widget>[
            const SectionLabel('Identity'),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Full name',
              controller: _name,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (String? v) =>
                  (v ?? '').trim().length < 3 ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppCountryField(
                  value: _phoneCode,
                  onChanged: (String v) => setState(() {
                    _phoneCode = v;
                    _dirty = true;
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    label: 'Phone',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (String? v) =>
                        (v ?? '').replaceAll(RegExp(r'\D'), '').length < 7
                            ? 'Enter a valid number'
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email (optional)',
              controller: _email,
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (String? v) {
                final String t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return t.contains('@') ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 22),
            const SectionLabel('Home'),
            const SizedBox(height: 10),
            AppTextField(
              label: 'City',
              controller: _city,
              icon: Icons.location_city_outlined,
              textInputAction: TextInputAction.next,
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 14),
            Text('COUNTRY',
                style: AppTheme.ts(10.5, FontWeight.w700,
                    color: AppTheme.slate500, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _countries
                  .map<Widget>((String c) => TagChip(
                        c,
                        selected: _country == c,
                        onTap: () => setState(() {
                          _country = c;
                          _dirty = true;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Background'),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Education',
              controller: _education,
              icon: Icons.school_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Profession',
              controller: _profession,
              icon: Icons.work_outline_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'About me',
              controller: _aboutMe,
              hint: 'Your deen, home values and what you seek…',
              minLines: 4,
              maxLines: 6,
              maxLength: 600,
              validator: (String? v) => (v ?? '').trim().length < 40
                  ? 'Please write at least 40 characters'
                  : null,
            ),
            const SizedBox(height: 22),
            const SectionLabel('Relocation'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relocations
                  .map<Widget>((String r) => TagChip(
                        r,
                        selected: _relocation == r,
                        onTap: () => setState(() {
                          _relocation = r;
                          _dirty = true;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 26),
            PrimaryButton(
              label: 'Save Changes',
              icon: Icons.check_rounded,
              onPressed: _dirty ? _save : null,
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              icon: Icons.visibility_off_outlined,
              text: 'Photo modesty controls live in Settings & Privacy.',
              variant: InfoVariant.neutral,
              tight: true,
            ),
          ],
        ),
      ),
    );
  }
}

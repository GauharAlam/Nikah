/// Onboarding step 2 — salah, Quran comfort, halal lifestyle and timeline.
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
import '../widgets/app_snacks.dart';
import '../widgets/onboarding_shell.dart';

class IslamicPracticeStepScreen extends StatefulWidget {
  const IslamicPracticeStepScreen({super.key});

  @override
  State<IslamicPracticeStepScreen> createState() =>
      _IslamicPracticeStepScreenState();
}

class _IslamicPracticeStepScreenState extends State<IslamicPracticeStepScreen> {
  static const List<String> _lifestyleOptions = <String>[
    'Strictly Halal & Zabiha',
    'No riba / halal finance',
    'Modest wardrobe policy',
    'Avoids music & free mixing',
    'Regular masjid attendance',
    'Weekly halaqah',
  ];

  static const List<String> _timelineOptions = <String>[
    'Nikah: 3-6 mos',
    'Nikah: 6-12 mos',
    'Nikah: 12 mos+',
  ];

  static const List<String> _relocationOptions = <String>[
    'Open to discuss',
    'Ready to relocate',
    'Staying in my city',
  ];

  PrayerFrequency _prayer = PrayerFrequency.always;
  QuranComfort _quran = QuranComfort.intermediate;
  Set<String> _lifestyle = <String>{};
  String _timeline = 'Nikah: 6-12 mos';
  String _relocation = 'Open to discuss';

  @override
  void initState() {
    super.initState();
    final WardProfile? draft = context.read<AppStore>().profile;
    _prayer = draft?.prayerFrequency ?? PrayerFrequency.always;
    _quran = draft?.quranComfort ?? QuranComfort.intermediate;
    _lifestyle = Set<String>.from(draft?.halalLifestyle ?? const <String>[]);
    final String? savedTimeline = draft?.timeline;
    if (savedTimeline != null && savedTimeline.isNotEmpty) {
      _timeline = savedTimeline;
    }
    final String? savedRelocation = draft?.relocation;
    if (savedRelocation != null && savedRelocation.isNotEmpty) {
      _relocation = savedRelocation;
    }
  }

  void _toggleLifestyle(String option) {
    setState(() {
      if (_lifestyle.contains(option)) {
        _lifestyle = <String>{..._lifestyle..remove(option)};
      } else {
        _lifestyle = <String>{..._lifestyle, option};
      }
    });
  }

  void _submit() {
    context
        .read<AppStore>()
        ..updateProfile(
          (WardProfile p) => p.copyWith(
            prayerFrequency: _prayer,
            quranComfort: _quran,
            halalLifestyle: _lifestyle.toList(growable: false),
            timeline: _timeline,
            relocation: _relocation,
          ),
        )
        ..markStepDone(3);
    showSuccessSnack(context, 'Practice profile saved. MashaAllah!');
    context.push(AppRoutes.onboardingPhotos);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 3,
      title: 'Deen & Practice',
      subtitle: 'Share your salah, Quran and halal commitments with ihsan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const InfoBanner(
            variant: InfoVariant.gold,
            icon: Icons.volunteer_activism_outlined,
            text:
                'This journey is an act of worship. Describe your practice '
                'honestly — sincerity before Allah brings barakah to every '
                'introduction.',
          ),
          const SizedBox(height: 24),
          const SectionLabel('Salah frequency', requiredMark: true),
          const SizedBox(height: 8),
          Column(
            children: PrayerFrequency.values.map<Widget>((PrayerFrequency f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrayerOption(
                  value: f,
                  selected: _prayer == f,
                  onTap: () => setState(() => _prayer = f),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Quran comfort', requiredMark: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuranComfort.values.map<Widget>((QuranComfort c) {
              return TagChip(
                c.label,
                selected: _quran == c,
                onTap: () => setState(() => _quran = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Halal lifestyle & commitments'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _lifestyleOptions.map<Widget>((String option) {
              final bool selected = _lifestyle.contains(option);
              return FilterChip(
                selected: selected,
                onSelected: (bool _) => _toggleLifestyle(option),
                backgroundColor: AppTheme.slate100,
                selectedColor: AppTheme.green,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: selected ? AppTheme.green : AppTheme.slate200,
                ),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                label: Text(
                  option,
                  style: AppTheme.ts(
                    12,
                    FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.slate700,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Marital timeline', requiredMark: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timelineOptions.map<Widget>((String option) {
              return TagChip(
                option,
                selected: _timeline == option,
                onTap: () => setState(() => _timeline = option),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Relocation', requiredMark: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _relocationOptions.map<Widget>((String option) {
              return TagChip(
                option,
                selected: _relocation == option,
                onTap: () => setState(() => _relocation = option),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const InfoBanner(
            tight: true,
            variant: InfoVariant.info,
            icon: Icons.verified_user_outlined,
            text:
                'Your Wali can see this starting point to guide '
                'introductions — nothing here is public.',
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Save & Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _PrayerOption extends StatelessWidget {
  const _PrayerOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final PrayerFrequency value;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (value) {
    PrayerFrequency.always => Icons.notifications_active_outlined,
    PrayerFrequency.mostly => Icons.schedule_outlined,
    PrayerFrequency.growing => Icons.trending_up,
  };

  @override
  Widget build(BuildContext context) {
    final String? detail = value.detail;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.successBg
                : AppTheme.slate100.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.green : AppTheme.slate200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.green : AppTheme.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _icon,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.slate600,
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
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppTheme.ts(
                          11.5,
                          FontWeight.w500,
                          color: AppTheme.slate500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppTheme.green,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

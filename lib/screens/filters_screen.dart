// Discovery filters — "Profile Settings" sheet with full-bleed
// two-line preference rows, diamond premium gates and a single Apply button.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app_router.dart';
import '../config/app_config.dart';
import '../data/option_lists.dart';
import '../l10n/app_strings.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_snacks.dart';
import '../widgets/app_switch.dart';

/// Profile Settings screen backing the discovery deck.
class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  static const String _any = MatchFilters.anyValue;

  static const List<String> _marriageStatuses = <String>[
    _any,
    'Never married',
    'Divorced',
    'Widowed',
  ];

  static final List<String> _castes = <String>[_any, ...OptionLists.castes];

  static final List<String> _almaMaters = <String>[
    _any,
    for (final List<String> group in OptionLists.universities.values) ...group,
  ];

  static final List<String> _educationLevels = <String>[
    _any,
    ...OptionLists.qualifications.entries
        .where((MapEntry<String, bool> q) => q.value)
        .map((MapEntry<String, bool> q) => q.key),
  ];

  static final List<String> _professionFields = <String>[_any, ...OptionLists.professions];

  static final List<String> _locations = <String>[_any, ...OptionLists.locations.keys];

  static final List<String> _sects = <String>[_any, ...OptionLists.sects];

  static const List<String> _contactModes = <String>[
    MatchFilters.manualApproval,
    'Share after proposal accepted',
    'Open to verified members',
  ];

  MatchFilters _draft = const MatchFilters();

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppStore>().filters;
  }

  int get _matchCount => context.read<AppStore>().directory
      .where((MatchProfile p) => _draft.acceptsProfile(p))
      .length;

  Future<void> _pickValue(
    String title,
    String current,
    List<String> options,
    void Function(String value) apply,
  ) async {
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
                title,
                style: AppTheme.ts(16, FontWeight.w800, color: AppTheme.slate900),
              ),
            ),
            for (final String option in options)
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  option,
                  style: AppTheme.ts(
                    14.5,
                    FontWeight.w600,
                    color: option == current ? AppTheme.green : AppTheme.slate700,
                  ),
                ),
                trailing: option == current
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppTheme.green,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => apply(picked));
  }

  void _clearAll() {
    context.read<AppStore>().setFilters(const MatchFilters());
    setState(() => _draft = const MatchFilters());
    showSuccessSnack(context, tr('Filters cleared — showing all profiles.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: tr('Close'),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.homeDiscovery);
            }
          },
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          tr('Profile Settings'),
          style: AppTheme.ts(16.5, FontWeight.w800, color: AppTheme.slate900),
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('open_search'),
            tooltip: tr('Search Rishtey'),
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.search),
          ),
          TextButton(
            key: const Key('reset_filters'),
            onPressed: _clearAll,
            child: Text(
              tr('Clear all'),
              style: AppTheme.ts(13, FontWeight.w800, color: AppTheme.slate700),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // ── Age ─────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      tr('Age'),
                      style: AppTheme.ts(14, FontWeight.w700, color: AppTheme.slate900),
                    ),
                    const Spacer(),
                    Text(
                      trArgs('{min}-{max} years', <String, Object>{'min': _draft.minAge, 'max': _draft.maxAge}),
                      style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.slate500),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: AppTheme.green,
                    inactiveTrackColor: AppTheme.slate200,
                    thumbColor: Colors.white,
                    overlayColor: AppTheme.green.withValues(alpha: 0.12),
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 11,
                      elevation: 3,
                      pressedElevation: 5,
                    ),
                  ),
                  child: RangeSlider(
                    key: const Key('age_range_slider'),
                    values: RangeValues(
                      _draft.minAge.toDouble(),
                      _draft.maxAge.toDouble(),
                    ),
                    min: 18,
                    max: 60,
                    divisions: 42,
                    labels: RangeLabels(
                      '${_draft.minAge}',
                      '${_draft.maxAge}',
                    ),
                    onChanged: (RangeValues values) => setState(
                      () => _draft = _draft.copyWith(
                        minAge: values.start.round(),
                        maxAge: values.end.round(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Full-bleed two-line preference rows ─────────────────────────
          Container(
            color: Colors.white,
            child: Column(
              children: <Widget>[
                _PreferenceRow(
                  label: tr('Marriage Status'),
                  value: _draft.marriageStatus,
                  onTap: () => _pickValue(
                    'Marriage Status',
                    _draft.marriageStatus,
                    _marriageStatuses,
                    (String v) => _draft = _draft.copyWith(marriageStatus: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Caste'),
                  value: _draft.caste,
                  onTap: () => _pickValue(
                    'Caste',
                    _draft.caste,
                    _castes,
                    (String v) => _draft = _draft.copyWith(caste: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Sect'),
                  value: _draft.sect,
                  onTap: () => _pickValue(
                    'Sect',
                    _draft.sect,
                    _sects,
                    (String v) => _draft = _draft.copyWith(sect: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Alma Mater'),
                  value: _draft.almaMater,
                  onTap: () => _pickValue(
                    'Alma Mater',
                    _draft.almaMater,
                    _almaMaters,
                    (String v) => _draft = _draft.copyWith(almaMater: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Education'),
                  value: _draft.education,
                  premium: true,
                  onTap: () => _pickValue(
                    'Education',
                    _draft.education,
                    _educationLevels,
                    (String v) => _draft = _draft.copyWith(education: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Profession'),
                  value: _draft.profession,
                  premium: true,
                  onTap: () => _pickValue(
                    'Profession',
                    _draft.profession,
                    _professionFields,
                    (String v) => _draft = _draft.copyWith(profession: v),
                  ),
                ),
                const _RowDivider(),
                _PreferenceRow(
                  label: tr('Location'),
                  value: _draft.location,
                  premium: true,
                  onTap: () => _pickValue(
                    'Location',
                    _draft.location,
                    _locations,
                    (String v) => _draft = _draft.copyWith(location: v),
                  ),
                ),
                if (AppConfig.guardianFeatures) const _RowDivider(),
                if (AppConfig.guardianFeatures) Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SwitchTile(
                    key: const Key('wali_verified_switch'),
                    icon: Icons.verified_user_outlined,
                    title: 'Wali-verified profiles only',
                    subtitle:
                        'Only show members whose guardian completed verification.',
                    value: _draft.waliVerifiedOnly,
                    onChanged: (bool value) => setState(
                      () => _draft = _draft.copyWith(waliVerifiedOnly: value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Contact sharing ─────────────────────────────────────────────
          Container(
            color: AppTheme.mint.withValues(alpha: 0.22),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.phone_in_talk_outlined,
                  size: 17,
                  color: AppTheme.emeraldDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Contact Sharing'),
                    style: AppTheme.ts(
                      15,
                      FontWeight.w800,
                      color: AppTheme.emeraldDeep,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _pickValue(
                    'Contact Sharing',
                    _draft.contactSharing,
                    _contactModes,
                    (String v) => _draft = _draft.copyWith(contactSharing: v),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tr('Edit'),
                        style: AppTheme.ts(12.5, FontWeight.w800, color: AppTheme.green),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppTheme.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: () => _pickValue(
                    'Contact Sharing',
                    _draft.contactSharing,
                    _contactModes,
                    (String v) => _draft = _draft.copyWith(contactSharing: v),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: <Widget>[
                        Text(
                          tr('Sharing'),
                          style: AppTheme.ts(
                            14,
                            FontWeight.w700,
                            color: AppTheme.slate900,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            _draft.contactSharing == MatchFilters.manualApproval
                                ? 'Manual approval'
                                : (_draft.contactSharing == _contactModes[1]
                                      ? 'After proposal'
                                      : 'Verified only'),
                            style: AppTheme.ts(
                              10.5,
                              FontWeight.w800,
                              color: AppTheme.goldInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.slate400,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    tr('Your number is shared only when you accept a request.'),
                    style: AppTheme.ts(
                      11.5,
                      FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          border: Border(
            top: BorderSide(color: AppTheme.slate200.withValues(alpha: 0.8)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                trArgs('{count} profiles match', <String, Object>{'count': _matchCount}),
                key: const Key('filter_match_count'),
                style: AppTheme.ts(11, FontWeight.w600, color: AppTheme.slate500),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                key: const Key('apply_filters'),
                label: tr('Apply'),
                onPressed: () {
                  final AppStore store = context.read<AppStore>();
                  store.setFilters(_draft);
                  showAppSnack(
                    context,
                    'Filters applied — deck refreshed in sha Allah.',
                    icon: Icons.filter_alt_rounded,
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.homeDiscovery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.slate100,
    );
  }
}

/// Full-bleed two-line row: bold label above, grey value below, optional
/// gold diamond for premium-gated preferences.
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.premium = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final bool isSet = value != MatchFilters.anyValue;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTheme.ts(
                      14,
                      FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ts(
                      12.5,
                      FontWeight.w600,
                      color: isSet ? AppTheme.green : AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (premium) ...<Widget>[
              const SizedBox(width: 8),
              const Icon(
                Icons.diamond_outlined,
                size: 15,
                color: AppTheme.goldAccent,
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.slate400,
            ),
          ],
        ),
      ),
    );
  }
}

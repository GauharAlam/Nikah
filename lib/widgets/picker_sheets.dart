import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../data/option_lists.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import 'app_snacks.dart';

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
            ),
          ),
          IconButton(
            tooltip: tr('Close'),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Lets the member choose the app language.
Future<void> pickLanguage(BuildContext context) async {
  final AppStore store = context.read<AppStore>();
  final String? picked = await showOptionSheet(
    context,
    title: tr('Language'),
    options: AppStrings.languageLabels,
  );
  if (picked == null) return;
  store.setLanguage(
    AppLanguage.values.firstWhere((AppLanguage l) => l.label == picked),
  );
}

/// Single choice from a list.
Future<String?> showOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (BuildContext ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SheetHeader(title),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, int i) => ListTile(
                  title: Text(tr(options[i])),
                  onTap: () => Navigator.of(ctx).pop(options[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Searchable university picker: up to [max] picks, grouped by country.
Future<List<String>?> showAlmaMaterSheet(
  BuildContext context, {
  required List<String> selected,
  int max = 2,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _AlmaMaterSheet(selected: selected, max: max),
  );
}

class _AlmaMaterSheet extends StatefulWidget {
  const _AlmaMaterSheet({required this.selected, required this.max});
  final List<String> selected;
  final int max;

  @override
  State<_AlmaMaterSheet> createState() => _AlmaMaterSheetState();
}

class _AlmaMaterSheetState extends State<_AlmaMaterSheet> {
  late final List<String> _picked = <String>[...widget.selected];
  String _query = '';

  void _toggle(String name) {
    setState(() {
      if (_picked.remove(name)) return;
      if (_picked.length < widget.max) _picked.add(name);
    });
  }

  Widget _row(String name) => CheckboxListTile(
        value: _picked.contains(name),
        title: Text(name),
        onChanged: (_) => _toggle(name),
      );

  @override
  Widget build(BuildContext context) {
    final String q = _query.toLowerCase();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _SheetHeader(tr('Select Alma Mater')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('alma_search'),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: tr('Search universities...'),
                ),
                onChanged: (String v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  _row(OptionLists.otherUniversity),
                  for (final MapEntry<String, List<String>> group
                      in OptionLists.universities.entries) ...<Widget>[
                    if (group.value.any((String u) => u.toLowerCase().contains(q)))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          group.key.toUpperCase(),
                          style: AppTheme.ts(11, FontWeight.w700, color: AppTheme.slate500),
                        ),
                      ),
                    for (final String u in group.value)
                      if (u.toLowerCase().contains(q)) _row(u),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: <Widget>[
                  Text(trArgs('{count}/{max} selected', <String, Object>{'count': _picked.length, 'max': widget.max}),
                      style: AppTheme.bodySmall),
                  const Spacer(),
                  FilledButton(
                    key: const Key('alma_done'),
                    onPressed: () => Navigator.of(context).pop(_picked),
                    child: Text(tr('Done')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PickedLocation {
  const PickedLocation(this.country, this.region, this.city);
  final String country;
  final String region;
  final String city;
}

/// Country → region → city picker, with coarse current location.
Future<PickedLocation?> showLocationSheet(
  BuildContext context, {
  required String title,
  PickedLocation? initial,
}) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _LocationSheet(title: title, initial: initial),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.title, this.initial});
  final String title;
  final PickedLocation? initial;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late String _country = widget.initial?.country ?? '';
  late String _region = widget.initial?.region ?? '';
  late String _city = widget.initial?.city ?? '';
  bool _locating = false;

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showAppSnack(context, 'Location is off. Choose your city below.');
        }
        return;
      }
      final Position at = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final List<Placemark> places =
          await Geocoding().placemarkFromCoordinates(at.latitude, at.longitude);
      if (places.isEmpty || !mounted) return;
      setState(() {
        _country = places.first.country ?? '';
        _region = places.first.administrativeArea ?? '';
        _city = places.first.locality ?? places.first.subAdministrativeArea ?? '';
      });
    } on Object {
      if (mounted) {
        showAppSnack(context, 'Could not find your location. Choose it below.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _row(String label, String value, String hint, VoidCallback? onTap) {
    final bool enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: AppTheme.ts(
                  14.5,
                  FontWeight.w600,
                  color: enabled ? AppTheme.slate900 : AppTheme.slate400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? hint : value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<String>> regions =
        OptionLists.locations[_country] ?? const <String, List<String>>{};
    final List<String> cities = regions[_region] ?? const <String>[];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SheetHeader(widget.title),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: _locating ? null : _useCurrent,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(_locating ? tr('Finding you…') : tr('Use current location')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                _row('Country', _country, tr('Select country'), () async {
                  final String? v = await showOptionSheet(
                    context,
                    title: tr('Country'),
                    options: OptionLists.locations.keys.toList(),
                  );
                  if (v != null) {
                    setState(() {
                      _country = v;
                      _region = '';
                      _city = '';
                    });
                  }
                }),
                _row(
                  'State / Region',
                  _region,
                  tr('Select state or region'),
                  regions.isEmpty
                      ? null
                      : () async {
                          final String? v = await showOptionSheet(
                            context,
                            title: tr('State / Region'),
                            options: regions.keys.toList(),
                          );
                          if (v != null) {
                            setState(() {
                              _region = v;
                              _city = '';
                            });
                          }
                        },
                ),
                _row(
                  'City',
                  _city,
                  tr('Select city'),
                  cities.isEmpty
                      ? null
                      : () async {
                          final String? v = await showOptionSheet(
                            context,
                            title: tr('City'),
                            options: cities,
                          );
                          if (v != null) setState(() => _city = v);
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _city.isEmpty
                    ? null
                    : () => Navigator.of(context)
                        .pop(PickedLocation(_country, _region, _city)),
                child: Text(tr('Done')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

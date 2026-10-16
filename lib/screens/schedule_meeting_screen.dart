// Schedule a chaperoned family meeting — format picker, real date and
// time pickers, optional notes and guardian-approved submission.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/match_profile.dart';
import '../models/meeting.dart';
import '../models/ward_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/app_snacks.dart';

class ScheduleMeetingScreen extends StatefulWidget {
  const ScheduleMeetingScreen({required this.matchId, super.key});

  final String matchId;

  @override
  State<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<ScheduleMeetingScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  MeetingFormat _format = MeetingFormat.video;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime base = _date ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Select meeting date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateController.text = AppStore.fmtDate(picked);
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay initial = _time ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Select meeting time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _timeController.text =
          AppStore.fmtTime(DateTime(1, 1, 1, picked.hour, picked.minute));
    });
  }

  void _submit() {
    final DateTime? date = _date;
    final TimeOfDay? time = _time;
    if (date == null || time == null) return;

    final String location = switch (_format) {
      MeetingFormat.video =>
        'Family video bridge — link shared with both Wali.',
      MeetingFormat.audio => 'Chaperoned audio link — numbers exchanged via Wali.',
      MeetingFormat.inPerson => 'Agreed family venue — confirmed by both sides.',
    };

    context.read<AppStore>().scheduleMeeting(
          MeetingRequest(
            id: 'mtg-${DateTime.now().millisecondsSinceEpoch}',
            matchId: widget.matchId,
            format: _format,
            scheduledAt: DateTime(date.year, date.month, date.day, time.hour, time.minute),
            location: location,
            notes: _notesController.text.trim(),
          ),
        );
    if (!mounted) return;
    showSuccessSnack(context, 'Meeting request sent — both Wali will confirm.');
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) context.pop();
    });
  }

  bool get _canSubmit => _date != null && _time != null;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final MatchProfile match = MatchProfile.byId(widget.matchId);
    final WardProfile ward = store.profile ?? WardProfile.demoWard;
    final String wardName = ward.displayName.isEmpty
        ? WardProfile.demoWard.displayName
        : ward.displayName;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Schedule Family Meeting')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          const InfoBanner(
            icon: Icons.verified_user_outlined,
            variant: InfoVariant.gold,
            text: 'Wali supervision — every format is chaperoned; both '
                'guardians receive the schedule and confirm coordination.',
          ),
          const SizedBox(height: 16),
          _ParticipantsCard(
            wardName: wardName,
            wardInitial: wardName.isEmpty ? 'A' : wardName.substring(0, 1),
            matchName: match.name,
            matchRole: '${match.firstName} (with Wali)',
            matchImage: match.imageUrl,
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Meeting format',
            subtitle: 'Chaperone-friendly way to meet first.',
          ),
          const SizedBox(height: 12),
          ...MeetingFormat.values.map(
            (MeetingFormat format) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FormatTile(
                format: format,
                selected: _format == format,
                onSelect: () => setState(() => _format = format),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            'Date & time',
            subtitle: 'Propose a slot that suits both families.',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _PickerField(
                  label: 'Date',
                  controller: _dateController,
                  hint: 'Pick a date',
                  icon: Icons.event_outlined,
                  suffix: Icons.calendar_month_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerField(
                  label: 'Time',
                  controller: _timeController,
                  hint: 'Pick a time',
                  icon: Icons.schedule_outlined,
                  suffix: Icons.access_time_outlined,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PickerField(
            label: 'Notes (optional)',
            controller: _notesController,
            hint: 'Agenda, family expectations, du\'a requests…',
            icon: Icons.notes_rounded,
            maxLength: 180,
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: const ValueKey<String>('submit_meeting'),
            label: 'Send Meeting Request',
            icon: Icons.send_rounded,
            onPressed: _canSubmit ? _submit : null,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('Changes require approval from both guardians.',
                style: AppTheme.caption),
          ),
        ],
      ),
    );
  }
}

/// Ward + match identity card with a chaperone shield divider between rows.
class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({
    required this.wardName,
    required this.wardInitial,
    required this.matchName,
    required this.matchRole,
    required this.matchImage,
  });

  final String wardName;
  final String wardInitial;
  final String matchName;
  final String matchRole;
  final String matchImage;

  Widget _row({
    required String url,
    required String initials,
    required String name,
    required String role,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    return Row(
      children: <Widget>[
        AppAvatar(url: url, radius: 24, initials: initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: alignment,
            children: <Widget>[
              Text(
                name,
                style: AppTheme.ts(14, FontWeight.w800, color: AppTheme.slate900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(role, style: AppTheme.caption),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          _row(
            url: '',
            initials: wardInitial,
            name: wardName,
            role: 'Sister (with Wali)',
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.shield_outlined, size: 16, color: AppTheme.goldDeep),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          _row(
            url: matchImage,
            initials: matchRole.substring(0, 1),
            name: matchName,
            role: matchRole,
            alignment: CrossAxisAlignment.start,
          ),
        ],
      ),
    );
  }
}

/// Hand-built single-select radio row for a MeetingFormat option.
class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onSelect,
  });

  final MeetingFormat format;
  final bool selected;
  final VoidCallback onSelect;

  static IconData _iconFor(MeetingFormat format) => switch (format) {
        MeetingFormat.video => Icons.video_camera_front_outlined,
        MeetingFormat.audio => Icons.phone_in_talk_outlined,
        MeetingFormat.inPerson => Icons.mosque,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.green.withValues(alpha: 0.07)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.green : AppTheme.slate200.withValues(alpha: 0.7),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.green : AppTheme.slate100,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconFor(format),
                  size: 20,
                  color: selected ? Colors.white : AppTheme.slate600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      format.label,
                      style: AppTheme.ts(
                        14,
                        FontWeight.w700,
                        color: selected ? AppTheme.emeraldDeep : AppTheme.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      format.detail,
                      style: AppTheme.ts(
                        11.5,
                        FontWeight.w500,
                        color: AppTheme.slate500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom radio indicator (filled ring + inner dot when selected).
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.green : Colors.white,
        border: Border.all(
          color: selected ? AppTheme.green : AppTheme.slate300,
          width: 2,
        ),
      ),
      child: selected
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// Labelled field mirroring AppTextField styling but adding suffixIcon and
/// multiline support (used for picker-only and notes inputs).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.onTap,
    this.maxLength,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final IconData? suffix;
  final VoidCallback? onTap;
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: AppTheme.ts(
            10.5,
            FontWeight.w700,
            color: AppTheme.slate500,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: onTap != null,
          onTap: onTap,
          maxLength: maxLength,
          maxLines: maxLines,
          style: AppTheme.ts(14.5, FontWeight.w600, color: AppTheme.slate900),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppTheme.slate400),
            suffixIcon:
                suffix == null ? null : Icon(suffix, size: 18, color: AppTheme.green),
            counterStyle: AppTheme.ts(10.5, FontWeight.w600, color: AppTheme.slate400),
          ),
        ),
      ],
    );
  }
}

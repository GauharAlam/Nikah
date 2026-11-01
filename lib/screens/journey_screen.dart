import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/backend.dart';
import '../models/match_profile.dart';
import '../models/nikah_journey.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';

/// Shared steps after a match, with the Important Questions.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final Map<String, TextEditingController> _fields = <String, TextEditingController>{
    for (final JourneyQuestion q in journeyQuestions) q.id: TextEditingController(),
  };
  Map<String, String>? _theirs;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final AppStore store = context.read<AppStore>();
    try {
      final Map<String, String> mine = await store.myAnswers(widget.matchId);
      final Map<String, String>? theirs =
          mine.isEmpty ? null : await store.theirAnswers(widget.matchId);
      if (!mounted) return;
      setState(() {
        mine.forEach((String id, String text) => _fields[id]?.text = text);
        _theirs = theirs;
      });
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final Map<String, String> answers = <String, String>{
      for (final MapEntry<String, TextEditingController> e in _fields.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (answers.isEmpty) {
      showAppSnack(context, 'Answer at least one question first.');
      return;
    }
    setState(() => _saving = true);
    final AppStore store = context.read<AppStore>();
    try {
      await store.saveAnswers(widget.matchId, answers);
      final Map<String, String>? theirs = await store.theirAnswers(widget.matchId);
      if (mounted) {
        setState(() => _theirs = theirs);
        showSuccessSnack(context, 'Your answers are saved.');
      }
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _stepRow(AppStore store, JourneyStep step) {
    final JourneyStep mine = store.journeyStep(widget.matchId);
    final JourneyStep? theirs = store.theirJourneyStep(widget.matchId);
    final bool done = step.index <= mine.index;
    return ListTile(
      key: Key('journey_${step.name}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: done ? AppTheme.green : AppTheme.slate300,
      ),
      title: Text(step.title),
      subtitle: Text(
        theirs != null && step.index <= theirs.index
            ? '${step.detail} They have reached this step too.'
            : step.detail,
      ),
      onTap: () => store.setJourneyStep(widget.matchId, step),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final MatchProfile match = store.profileById(widget.matchId);
    final Map<String, String>? theirs = _theirs;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text('Journey with ${match.firstName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: <Widget>[
                for (final JourneyStep step in JourneyStep.values) _stepRow(store, step),
                const SizedBox(height: 16),
                Text(
                  'Important Questions',
                  style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 4),
                Text(
                  theirs == null
                      ? 'You will see ${match.firstName}\'s answers once you have '
                          'both answered. Answer only what you are comfortable sharing.'
                      : 'Use these to talk, with your families where it helps.',
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < journeyQuestions.length; i++) ...() {
                  final JourneyQuestion q = journeyQuestions[i];
                  return <Widget>[
                  if (i == 0 || journeyQuestions[i - 1].topic != q.topic)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Text(
                        q.topic.toUpperCase(),
                        style: AppTheme.ts(11, FontWeight.w800, color: AppTheme.green),
                      ),
                    ),
                  Text(q.text, style: AppTheme.ts(14, FontWeight.w600, color: AppTheme.slate900)),
                  const SizedBox(height: 6),
                  TextField(
                    key: Key('answer_${q.id}'),
                    controller: _fields[q.id],
                    maxLength: 500,
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'Your answer', counterText: ''),
                  ),
                  if (theirs?[q.id] != null) ...<Widget>[
                    const SizedBox(height: 6),
                    AppCard(child: Text('${match.firstName}: ${theirs![q.id]}', style: AppTheme.bodySmall)),
                  ],
                  const SizedBox(height: 12),
                  ];
                }(),
                PrimaryButton(
                  key: const Key('save_answers'),
                  label: _saving ? 'Saving…' : 'Save my answers',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../data/option_lists.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import 'app_snacks.dart';

/// Asks why, optionally for more, and sends the report. Shows success only
/// once the server has it. Used from a profile and from a conversation.
Future<void> showReportSheet(
  BuildContext context,
  AppStore store,
  String matchId, {
  String reportContext = 'profile',
}) async {
  final ({String reason, String details})? answer = await showModalBottomSheet<({String reason, String details})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ReportSheet(),
  );
  if (answer == null || !context.mounted) return;
  try {
    await store.reportProfile(matchId, answer.reason, details: answer.details, context: reportContext);
    if (context.mounted) {
      showAppSnack(
        context,
        tr('Report sent. Our team will review it. They will not be told who reported.'),
        icon: Icons.flag_outlined,
      );
    }
  } on BackendException catch (e) {
    if (context.mounted) showAppSnack(context, e.message);
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _details = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(tr('What happened?'), style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900)),
            const SizedBox(height: 6),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (String? v) => setState(() => _reason = v),
              child: Column(
                children: <Widget>[
                  for (final String r in OptionLists.reportReasons)
                    RadioListTile<String>(
                      key: Key('reason_$r'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(r)),
                      value: r,
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('report_details'),
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(hintText: tr('Anything else we should know (optional)')),
            ),
            FilledButton(
              key: const Key('report_send'),
              onPressed: _reason == null
                  ? null
                  : () => Navigator.of(context).pop((reason: _reason!, details: _details.text.trim())),
              child: Text(tr('Send report')),
            ),
          ],
        ),
      ),
    );
  }
}

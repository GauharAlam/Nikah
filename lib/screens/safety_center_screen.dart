import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

/// Fraud patterns from India's cybercrime advisory and what to do about them.
class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  static const List<(IconData, String, String)> _signs = <(IconData, String, String)>[
    (Icons.payments_outlined, 'They ask for money',
        'An emergency, customs fee, hospital bill or visa cost. Never send money to someone you have not met with your family.'),
    (Icons.trending_up_rounded, 'They suggest an investment',
        'Crypto, trading or "guaranteed returns" from a new match is a known scam.'),
    (Icons.flight_takeoff_rounded, 'The story is too perfect',
        'A doctor, engineer or NRI who cannot meet or video call, and always has a reason.'),
    (Icons.chat_outlined, 'They rush you off the app',
        'Scammers move to WhatsApp early, where reports cannot help you.'),
    (Icons.key_outlined, 'They ask for a code',
        'Never share an OTP or bank details. Our team will never ask for them.'),
  ];

  static const List<String> _steps = <String>[
    'Involve your family before you share anything personal.',
    'Video call before you trust a story, and meet in a public place with family.',
    'Report and block from the ⋮ menu on their profile.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(tr('Safety Centre'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            tr('Warning signs'),
            style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 10),
          for (final (IconData icon, String title, String body) in _signs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icon, color: AppTheme.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(tr(title), style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900)),
                          const SizedBox(height: 3),
                          Text(tr(body), style: AppTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            tr('Stay safe'),
            style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 8),
          for (final String step in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr(step), style: AppTheme.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            tr('If you lost money'),
            style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 6),
          Text(
            tr('In India, call the cybercrime helpline 1930 as soon as you can, '
            'or report online.'),
            style: AppTheme.bodySmall,
          ),
          TextButton.icon(
            key: const Key('open_cybercrime_portal'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('cybercrime.gov.in'),
            onPressed: () => unawaited(launchUrl(
              Uri.parse('https://cybercrime.gov.in'),
              mode: LaunchMode.externalApplication,
            )),
          ),
        ],
      ),
    );
  }
}

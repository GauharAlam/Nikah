// Premium tab — Barkat-style white plan card with the AVAILABLE credits
// panel, WHAT'S INCLUDED checklist and WHY UPGRADE section.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';

/// Premium tab of the home shell.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final int credits = store.contactCredits;
    final int total = AppStore.monthlyContactCredits;

    return Scaffold(
      backgroundColor: AppTheme.ivoryWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.ivoryWarm,
        automaticallyImplyLeading: false,
        actions: <Widget>[
          NotificationBell(
            unread: store.unreadNotificationCount,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            key: const Key('premium_settings'),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
        children: <Widget>[
          Text(
            'Premium',
            style: AppTheme.ts(24, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 3),
          Text(
            'Manage subscription & credits usage',
            style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.slate500),
          ),
          const SizedBox(height: 14),

          // ── Plan card: current plan · contact requests · what's included ─
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'CURRENT PLAN',
                      style: AppTheme.ts(
                        9.5,
                        FontWeight.w800,
                        color: AppTheme.slate500,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'Free plan',
                  style:
                      AppTheme.ts(21, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 3),
                Text(
                  'No subscription active',
                  style:
                      AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: AppTheme.slate200.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 14),

                // Contact requests + AVAILABLE side panel.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Contact Requests',
                            style: AppTheme.ts(
                              15,
                              FontWeight.w800,
                              color: AppTheme.slate900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Will be used to send contact requests.',
                            style: AppTheme.ts(
                              11.5,
                              FontWeight.w500,
                              color: AppTheme.slate500,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => showAppSnack(
                              context,
                              'In-app purchases are not available in this '
                              'build. No plan has been purchased.',
                              icon: Icons.receipt_long_outlined,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 14,
                                  color: AppTheme.green,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Purchase history',
                                  style: AppTheme.ts(
                                    12,
                                    FontWeight.w700,
                                    color: AppTheme.green,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _AvailablePanel(
                      credits: credits,
                      total: total,
                      onBuyMore: () => showSuccessSnack(
                        context,
                        'Checkout is disabled in this demo build.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: AppTheme.slate200.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 14),
                Text(
                  'WHAT\'S INCLUDED',
                  style: AppTheme.ts(
                    9.5,
                    FontWeight.w800,
                    color: AppTheme.slate500,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                const _CheckRow('Limited profile proposals.'),
                const _CheckRow('Restricted Contact Requests.'),
                const _CheckRow('Basic profile visibility'),
                const SizedBox(height: 14),

                // Daily quota info tiles.
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuotaTile(
                        icon: Icons.favorite_rounded,
                        label: 'Daily Proposals',
                        value:
                            '${AppStore.proposalQuota} per day',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuotaTile(
                        icon: Icons.phone_in_talk_outlined,
                        label: 'Contact Credits',
                        value: '$total / month',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Why upgrade ─────────────────────────────────────────────────
          Center(
            child: Text(
              'WHY UPGRADE',
              style: AppTheme.ts(
                10.5,
                FontWeight.w800,
                color: AppTheme.green,
              ).copyWith(letterSpacing: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'More clarity. Better visibility.',
            textAlign: TextAlign.center,
            style: AppTheme.ts(21, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to lift your profile higher in search, reach serious '
            'matches faster and keep every introduction supervised by your '
            'Wali from first salam to nikah.',
            textAlign: TextAlign.center,
            style: AppTheme.ts(
              12.5,
              FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Compare Plans',
            icon: Icons.workspace_premium_outlined,
            onPressed: () => showSuccessSnack(
              context,
              'Checkout is disabled in this demo build.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Mint side panel with the AVAILABLE credits meter and Buy more button.
class _AvailablePanel extends StatelessWidget {
  const _AvailablePanel({
    required this.credits,
    required this.total,
    required this.onBuyMore,
  });

  final int credits;
  final int total;
  final VoidCallback onBuyMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AVAILABLE',
            style: AppTheme.ts(
              8.5,
              FontWeight.w800,
              color: AppTheme.success,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$credits',
            style: AppTheme.ts(30, FontWeight.w800, color: AppTheme.green),
          ),
          Text(
            'remaining out of $total',
            style: AppTheme.ts(
              10,
              FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: AppTheme.green,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBuyMore,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child:                   Text(
                    'Buy more',
                    textAlign: TextAlign.center,
                    style: AppTheme.ts(
                      11.5,
                      FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green check row of the WHAT'S INCLUDED list.
class _CheckRow extends StatelessWidget {
  const _CheckRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppTheme.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 13,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.slate700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey tile with the daily quota of proposals / contact credits.
class _QuotaTile extends StatelessWidget {
  const _QuotaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 13, color: AppTheme.slate600),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: AppTheme.ts(
                    10.5,
                    FontWeight.w600,
                    color: AppTheme.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.ts(13, FontWeight.w800, color: AppTheme.slate900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../app_router.dart';
import '../data/backend.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Shown between submission and the reviewer's decision.
class ReviewStatusScreen extends StatelessWidget {
  const ReviewStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final bool changes = store.reviewStage == ReviewStage.changesRequested;
    final bool rejected = changes || store.reviewStage == ReviewStage.rejected;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                rejected ? Icons.edit_note_rounded : Icons.hourglass_top_rounded,
                size: 64,
                color: rejected ? AppTheme.goldDeep : AppTheme.green,
              ),
              const SizedBox(height: 18),
              Text(
                changes
                    ? tr('Please update your profile')
                    : rejected
                        ? tr('Your profile was not approved')
                        : tr('Your profile is under review'),
                textAlign: TextAlign.center,
                style: AppTheme.ts(22, FontWeight.w800, color: AppTheme.slate900),
              ),
              const SizedBox(height: 10),
              Text(
                rejected
                    ? store.rejectionReason
                    : 'Our team reviews every profile before it goes live. '
                        'We will notify you when it is done.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 26),
              if (rejected)
                PrimaryButton(
                  key: const Key('edit_after_rejection'),
                  label: tr('Update my profile'),
                  onPressed: () => context.go(AppRoutes.onboarding),
                ),
              TextButton(
                onPressed: () => context.push(AppRoutes.verifyProfile),
                child: Text(tr('Add verification documents')),
              ),
              TextButton(
                onPressed: store.signOut,
                child: Text(tr('Log out')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

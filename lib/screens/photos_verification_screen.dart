/// Onboarding step 4 — profile photo slots and verification documents.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/verification_doc.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';
import '../widgets/onboarding_shell.dart';

class PhotosVerificationStepScreen extends StatefulWidget {
  const PhotosVerificationStepScreen({super.key});

  @override
  State<PhotosVerificationStepScreen> createState() =>
      _PhotosVerificationStepScreenState();
}

class _PhotosVerificationStepScreenState
    extends State<PhotosVerificationStepScreen> {
  static const List<String> _slotLabels = <String>[
    'Main photo',
    'Graduation photo',
    'Family photo',
  ];

  final Set<int> _uploaded = <int>{0};

  void _toggleSlot(int index) {
    setState(() {
      if (_uploaded.contains(index)) {
        _uploaded.remove(index);
        showAppSnack(context, '${_slotLabels[index]} removed.',
            icon: Icons.photo_camera_back_outlined);
      } else {
        _uploaded.add(index);
        showAppSnack(context, '${_slotLabels[index]} added (demo upload).',
            icon: Icons.photo_camera_outlined);
      }
    });
  }

  void _submit() {
    context.read<AppStore>().markStepDone(4);
    showSuccessSnack(context, 'Photos & verification saved.');
    context.push(AppRoutes.onboardingWali);
  }

  IconData _docIcon(String id) {
    if (id.contains('name')) return Icons.badge_outlined;
    if (id.contains('education')) return Icons.school_outlined;
    if (id.contains('photo')) return Icons.photo_camera_outlined;
    return Icons.payments_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<VerificationDoc> docs = store.verificationDocs;

    return OnboardingShell(
      step: 4,
      title: 'Photos & Verification',
      subtitle: 'Verified members receive three times more proposals.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const InfoBanner(
            variant: InfoVariant.info,
            icon: Icons.privacy_tip_outlined,
            text: 'Photos stay softly blurred for members outside your '
                'approved circle. Screenshots of photos are blocked on the '
                'Barkat Nikah app.',
          ),
          const SizedBox(height: 22),
          const SectionLabel('Profile Photos'),
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _slotLabels.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSlot(
                      key: Key('photo_slot_$i'),
                      label: _slotLabels[i],
                      uploaded: _uploaded.contains(i),
                      onTap: () => _toggleSlot(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Main photo is required before our team reviews your profile. '
            'Graduation and family photos strengthen your biodata.',
            style: AppTheme.ts(
              11.5,
              FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Verification Documents'),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < docs.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppTheme.slate100,
                    ),
                  _DocRow(
                    doc: docs[i],
                    icon: _docIcon(docs[i].id),
                    onUpload: () {
                      context
                          .read<AppStore>()
                          .submitVerificationDoc(docs[i].id);
                      showAppSnack(
                        context,
                        '${docs[i].title} sent for review.',
                        icon: Icons.upload_file_outlined,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            tight: true,
            variant: InfoVariant.gold,
            icon: Icons.workspace_premium_outlined,
            text: 'Prefer to finish later? Verification can be completed any '
                'time from Profile → Verify Profile.',
          ),
          const SizedBox(height: 18),
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

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    super.key,
    required this.label,
    required this.uploaded,
    required this.onTap,
  });

  final String label;
  final bool uploaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: uploaded
                  ? AppTheme.sage
                  : AppTheme.slate300,
              width: uploaded ? 1.4 : 1,
            ),
            gradient: uploaded
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppTheme.mint, AppTheme.sage],
                  )
                : null,
            color: uploaded ? null : AppTheme.slate100,
          ),
          child: uploaded
              ? Stack(
                  children: <Widget>[
                    const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 34,
                        color: AppTheme.emeraldDeep,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 10,
                              color: AppTheme.success,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Added',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: AppTheme.slate400,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTheme.ts(
                          9.5,
                          FontWeight.w700,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.icon,
    required this.onUpload,
  });

  final VerificationDoc doc;
  final IconData icon;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (doc.status) {
      VerificationDocStatus.approved => (
          AppTheme.successBg,
          AppTheme.success,
          'Verified',
        ),
      VerificationDocStatus.pending => (
          AppTheme.warningBg,
          AppTheme.warning,
          'Under review',
        ),
      VerificationDocStatus.missing => doc.isRequired
          ? (AppTheme.dangerBg, AppTheme.danger, 'Required')
          : (AppTheme.slate100, AppTheme.slate500, 'Optional'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.ivoryWarm,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppTheme.goldAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 18, color: AppTheme.goldDeep),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  doc.title,
                  style: AppTheme.ts(
                    13,
                    FontWeight.w700,
                    color: AppTheme.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: AppTheme.ts(9.5, FontWeight.w800, color: fg),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (doc.status == VerificationDocStatus.missing)
            TextButton(
              key: Key('upload_doc_${doc.id}'),
              onPressed: onUpload,
              child: Text(
                'Upload',
                style: AppTheme.ts(12.5, FontWeight.w800, color: AppTheme.green),
              ),
            )
          else if (doc.status == VerificationDocStatus.pending)
            const Icon(
              Icons.hourglass_top_rounded,
              size: 17,
              color: AppTheme.warning,
            )
          else
            const Icon(
              Icons.verified_rounded,
              size: 17,
              color: AppTheme.success,
            ),
        ],
      ),
    );
  }
}

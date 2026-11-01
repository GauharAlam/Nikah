// Verification screen: trust header with the verified pill, benefits list,
// per-document cards and FAQs.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/backend.dart';
import '../models/verification_doc.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snacks.dart';

/// Full-screen verification checklist (route: /profile/verify).
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  static const int _maxBytes = 10 * 1024 * 1024;

  /// Asks where the file comes from. Returns local paths, or null if cancelled.
  Future<List<String>?> _choose(BuildContext context) async {
    final String? source = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const Key('doc_camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              key: const Key('doc_gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photos'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              key: const Key('doc_file'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF'),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
          ],
        ),
      ),
    );
    switch (source) {
      case 'camera':
        final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);
        return photo == null ? null : <String>[photo.path];
      case 'gallery':
        final List<XFile> files = await ImagePicker().pickMultiImage(limit: 2);
        return files.take(2).map((XFile f) => f.path).toList();
      case 'file':
        final List<PlatformFile> picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: <String>['pdf'],
        );
        final String? path = picked.isEmpty ? null : picked.first.path;
        return path == null ? null : <String>[path];
    }
    return null;
  }

  /// Size is checked here for a quick answer; Storage rules enforce it.
  Future<bool> _tooLarge(List<String> paths) async {
    for (final String p in paths) {
      if (await File(p).length() > _maxBytes) return true;
    }
    return false;
  }

  Future<bool> _preview(BuildContext context, VerificationDoc doc, List<String> paths) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(doc.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String p in paths)
              p.toLowerCase().endsWith('.pdf')
                  ? ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(p.split('/').last),
                    )
                  : Image.file(File(p), height: 160, fit: BoxFit.contain),
            const SizedBox(height: 8),
            const Text('Only our review team can open this file. It is never shown to members.'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('doc_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _upload(
    BuildContext context,
    AppStore store,
    VerificationDoc doc,
  ) async {
    final List<String>? paths = await _choose(context);
    if (paths == null || paths.isEmpty || !context.mounted) return;
    if (await _tooLarge(paths)) {
      if (context.mounted) showAppSnack(context, 'Files must be under 10 MB.');
      return;
    }
    if (!context.mounted || !await _preview(context, doc, paths)) return;
    if (!context.mounted) return;
    showAppSnack(context, 'Uploading ${doc.title}…', icon: Icons.upload_rounded);
    try {
      await store.uploadVerificationDoc(doc.id, paths);
      if (context.mounted) {
        showSuccessSnack(
          context,
          AppConfig.isDemo
              ? 'Demo build: nothing was uploaded.'
              : '${doc.title} uploaded. Our team will review it.',
        );
      }
    } on BackendException catch (e) {
      if (context.mounted) showAppSnack(context, e.message);
    } on Object {
      if (context.mounted) showAppSnack(context, 'Upload failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<VerificationDoc> docs = store.verificationDocs;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Verification',
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
        children: <Widget>[
          // ── Centered trust-signal header ────────────────────────────────
          Center(
            child: Text(
              'YOUR TRUST SIGNAL',
              style: AppTheme.ts(
                10,
                FontWeight.w800,
                color: AppTheme.green,
              ).copyWith(letterSpacing: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get the Nikah Verified Badge',
            textAlign: TextAlign.center,
            style: AppTheme.ts(21, FontWeight.w800, color: AppTheme.slate900),
          ),
          const SizedBox(height: 8),
          Text(
            store.isVerifiedMember
                ? 'MashaAllah — every required document is approved. Your '
                      'badge is live on your profile.'
                : 'Verify your profile to earn the Nikah Verified badge — '
                      'a mark of trust that members recognise instantly.',
            textAlign: TextAlign.center,
            style: AppTheme.ts(
              12.5,
              FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.goldAccent.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: AppTheme.goldInk,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Verified',
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.ts(11.5, FontWeight.w800, color: AppTheme.goldInk),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Text(
              '${store.verificationProgress}% complete',
              style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate500),
            ),
          ),
          const SizedBox(height: 19),

          // ── Why verify ──────────────────────────────────────────────────
          const _BenefitRow(
            icon: Icons.verified_user_outlined,
            title: 'Prove you are who you say you are',
            body: 'ID and education documents reviewed by our team.',
          ),
          const _BenefitRow(
            icon: Icons.favorite_outline_rounded,
            title: 'Build confidence with serious seekers',
            body: 'A badge on your profile shows our team reviewed your documents.',
            last: true,
          ),
          const SizedBox(height: 20),

          // ── Steps ───────────────────────────────────────────────────────
          SectionLabel('Verification Steps'),
          const SizedBox(height: 4),
          Text(
            'Upload your documents below to complete verification.',
            style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500),
          ),
          const SizedBox(height: 12),
          for (final VerificationDoc doc in docs) ...<Widget>[
            _DocCard(
              doc: doc,
              onTap: () {
                if (doc.status.needsUpload) {
                  unawaited(_upload(context, store, doc));
                } else if (doc.status.isWaiting) {
                  showAppSnack(
                    context,
                    '${doc.title} is waiting for review by our team.',
                    icon: Icons.hourglass_bottom_rounded,
                  );
                } else {
                  showAppSnack(
                    context,
                    '${doc.title} is already approved.',
                    icon: Icons.verified_rounded,
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),

          // ── Good to know ────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Good to know',
                  style: AppTheme.ts(14, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 12),
                const _KnowRow(
                  icon: Icons.image_outlined,
                  text: 'Clear, well-lit photos. Any image up to 10 MB.',
                ),
                const _KnowRow(
                  icon: Icons.schedule_outlined,
                  text: 'Usually reviewed within 24–48 hours.',
                ),
                const _KnowRow(
                  icon: Icons.lock_outline_rounded,
                  text: 'Documents stay private and are never shared with '
                      'members.',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon in a circle + title/body used in the "why verify" list.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppTheme.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTheme.ts(13, FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTheme.ts(
                    11.5,
                    FontWeight.w500,
                    color: AppTheme.slate500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Document card with tinted icon square, status detail and an affordance
/// on the right (Upload › / View › / green check when verified).
class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.onTap});

  final VerificationDoc doc;
  final VoidCallback onTap;

  static IconData _iconFor(String id) => switch (id) {
        'name-proof' => Icons.badge_outlined,
        'education-proof' => Icons.school_outlined,
        'photo-proof' => Icons.photo_camera_outlined,
        'income-proof' => Icons.account_balance_wallet_outlined,
        _ => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final bool approved = doc.status == VerificationDocStatus.approved;
    final bool pending = doc.status.isWaiting;
    final Color fg = approved
        ? AppTheme.success
        : (pending ? AppTheme.warning : AppTheme.slate500);
    final Color iconField = approved
        ? AppTheme.successBg
        : AppTheme.mint.withValues(alpha: 0.3);

    return AppCard(
      key: Key('verification_doc_${doc.id}'),
      backgroundColor: approved ? AppTheme.successBg : null,
      borderColor: approved
          ? AppTheme.sage.withValues(alpha: 0.5)
          : AppTheme.slate200.withValues(alpha: 0.8),
      padding: const EdgeInsets.all(13),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconField,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _iconFor(doc.id),
                size: 21,
                color: approved ? AppTheme.success : AppTheme.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    doc.title,
                    style: AppTheme.ts(
                      13.5,
                      FontWeight.w800,
                      color: AppTheme.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.subtitle,
                    style: AppTheme.ts(
                      11.5,
                      FontWeight.w500,
                      color: AppTheme.slate500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    doc.rejectionReason.isEmpty ? doc.status.detail : doc.rejectionReason,
                    style: AppTheme.ts(11, FontWeight.w700, color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (approved)
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              )
            else
              ConstrainedBox(
                // Large text must not push this off a small screen.
                constraints: const BoxConstraints(maxWidth: 72),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        pending ? 'View' : 'Upload',
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.ts(12, FontWeight.w800, color: AppTheme.green),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: AppTheme.green,
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

class _KnowRow extends StatelessWidget {
  const _KnowRow({required this.icon, required this.text, this.last = false});

  final IconData icon;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: AppTheme.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: AppTheme.ts(
                  12,
                  FontWeight.w500,
                  color: AppTheme.slate600,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

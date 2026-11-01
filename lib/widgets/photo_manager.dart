import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

/// A member's photos. The first is the primary photo. Shared by onboarding and
/// profile editing.
class PhotoManager extends StatelessWidget {
  const PhotoManager({
    super.key,
    required this.photos,
    required this.rejected,
    required this.onRemove,
    required this.onReorder,
    this.progress,
  });

  final List<String> photos;

  /// Photos a reviewer asked the member to replace.
  final List<String> rejected;
  final ValueChanged<String> onRemove;

  /// Called with the new order.
  final ValueChanged<List<String>> onReorder;

  /// Upload progress from 0 to 1, or null when nothing is uploading.
  final double? progress;

  void _makePrimary(String photo) =>
      onReorder(<String>[photo, ...photos.where((String p) => p != photo)]);

  void _moveEarlier(int index) {
    final List<String> next = List<String>.from(photos);
    next.insert(index - 1, next.removeAt(index));
    onReorder(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(
              key: const Key('photo_progress'),
              value: progress,
              color: AppTheme.green,
            ),
          ),
        if (photos.any(rejected.contains))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              tr('Our team asked you to replace the photos marked in red.'),
              style: AppTheme.ts(12.5, FontWeight.w600, color: AppTheme.danger),
            ),
          ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              _PhotoTile(
                key: Key('photo_tile_$i'),
                stored: photos[i],
                primary: i == 0,
                rejected: rejected.contains(photos[i]),
                onRemove: () => onRemove(photos[i]),
                onMakePrimary: i == 0 ? null : () => _makePrimary(photos[i]),
                onMoveEarlier: i == 0 ? null : () => _moveEarlier(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.stored,
    required this.primary,
    required this.rejected,
    required this.onRemove,
    this.onMakePrimary,
    this.onMoveEarlier,
  });

  final String stored;
  final bool primary;
  final bool rejected;
  final VoidCallback onRemove;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onMoveEarlier;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: rejected ? Border.all(color: AppTheme.danger, width: 3) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder<String>(
              future: context.read<AppStore>().photoSource(stored),
              builder: (_, AsyncSnapshot<String> snap) {
                final String? src = snap.data;
                if (src == null) return const ColoredBox(color: AppTheme.slate200);
                if (src.startsWith('http')) return Image.network(src, fit: BoxFit.cover);
                if (kIsWeb) return const ColoredBox(color: AppTheme.slate200);
                return Image.file(File(src), fit: BoxFit.cover);
              },
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton.filledTonal(
            tooltip: tr('Remove photo'),
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (primary)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tr('Primary'),
                style: AppTheme.ts(10, FontWeight.w800, color: Colors.white),
              ),
            ),
          )
        else ...<Widget>[
          Positioned(
            left: 2,
            bottom: 2,
            child: IconButton.filledTonal(
              tooltip: tr('Make primary'),
              iconSize: 16,
              onPressed: onMakePrimary,
              icon: const Icon(Icons.star_outline_rounded),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: IconButton.filledTonal(
              tooltip: tr('Move earlier'),
              iconSize: 16,
              onPressed: onMoveEarlier,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Themed snackbars.
void showAppSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
  Color? background,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2600),
        backgroundColor: background ?? AppTheme.slate900,
        content: Row(
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTheme.ts(13, FontWeight.w600, color: Colors.white, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
}

void showSuccessSnack(BuildContext context, String message) =>
    showAppSnack(context, message, icon: Icons.check_circle_outline_rounded);

void showWaliSnack(BuildContext context, String message) =>
    showAppSnack(
      context,
      message,
      icon: Icons.verified_user_outlined,
      background: AppTheme.emerald,
    );

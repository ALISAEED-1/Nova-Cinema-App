import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Compact toast-style snackbar, replacing any one currently shown.
void showAppSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor:
            isError ? const Color(0xFF3A1214) : AppColors.surfaceHighlight,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isError ? AppColors.error : Colors.white),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'app_image.dart';

/// Rounded-square avatar using the profile artwork shipped with the project.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 34, this.onTap, this.accent = false});

  final double size;
  final VoidCallback? onTap;

  /// Draws the brand-red outline (profile header).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: accent ? AppColors.primary : AppColors.borderStrong,
            width: accent ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.all(accent ? 2 : 0),
        child: AppImage(
          AppConstants.defaultAvatarAsset,
          borderRadius: BorderRadius.circular(size * 0.22 - AppRadius.sm / 3),
          fadeIn: false,
        ),
      ),
    );
  }
}

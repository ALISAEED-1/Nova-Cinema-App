import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Asset image with a fade-in, a neutral placeholder and an error fallback.
///
/// On mobile the decoded bitmap is capped at the widget's on-screen pixel size
/// so large posters don't hold full-resolution bitmaps in memory. The cap is
/// skipped on web, where resized decoding is unreliable in the CanvasKit
/// renderer.
class AppImage extends StatelessWidget {
  const AppImage(
    this.assetPath, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.fadeIn = true,
  });

  final String assetPath;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final targetWidth = !kIsWeb && constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr).round()
            : null;
        return Image.asset(
          assetPath,
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          cacheWidth: targetWidth != null && targetWidth > 0
              ? targetWidth
              : null,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (!fadeIn || wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const _ImageFallback(),
        );
      },
    );

    final withBackground = ColoredBox(
      color: AppColors.shimmerBase,
      child: image,
    );

    if (borderRadius == null) return withBackground;
    return ClipRRect(borderRadius: borderRadius!, child: withBackground);
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: AppColors.textMuted,
          size: 28,
        ),
      ),
    );
  }
}

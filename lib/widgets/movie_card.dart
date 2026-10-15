import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/movie.dart';
import 'app_image.dart';
import 'rating_widget.dart';

/// Landscape movie card: artwork with title and year underneath.
///
/// [progress] (0–1) draws a resume bar over the artwork for continue-watching.
class MovieCard extends StatefulWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width = 168,
    this.progress,
    this.subtitle,
    this.showMeta = true,
    this.heroTag,
  });

  final Movie movie;
  final VoidCallback onTap;
  final double width;
  final double? progress;
  final String? subtitle;
  final bool showMeta;
  final Object? heroTag;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final movie = widget.movie;

    Widget art = AppImage(
      movie.imagePath,
      borderRadius: AppRadius.card,
    );
    if (widget.heroTag != null) {
      art = Hero(tag: widget.heroTag!, child: art);
    }

    return SizedBox(
      width: widget.width,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    art,
                    if (widget.progress != null)
                      _ProgressOverlay(fraction: widget.progress!),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                )
              else if (widget.showMeta)
                Row(
                  children: [
                    Text('${movie.year}', style: text.bodySmall),
                    const SizedBox(width: 6),
                    RatingBadge(movie.ageRating, compact: true),
                    if (movie.isSeries) ...[
                      const SizedBox(width: 6),
                      Text('Series', style: text.bodySmall),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressOverlay extends StatelessWidget {
  const _ProgressOverlay({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xB3000000)],
              stops: [0.5, 1],
            ),
          ),
        ),
        const Center(
          child: Icon(Icons.play_circle_fill_rounded, size: 40, color: Colors.white),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 3,
              backgroundColor: const Color(0x66FFFFFF),
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton stand-in for [MovieCard] while data loads.
class MovieCardSkeleton extends StatelessWidget {
  const MovieCardSkeleton({super.key, this.width = 168});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: AppRadius.card,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: width * 0.7,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: width * 0.4,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

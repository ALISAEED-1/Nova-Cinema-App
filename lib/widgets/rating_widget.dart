import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/movie.dart';

/// Outlined age-rating badge, e.g. `13+`.
class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key, this.compact = false});

  final String rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (rating.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        rating,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// `2024 • 13+ • 2h 35m • Sci-Fi` style meta line.
class MovieMetaRow extends StatelessWidget {
  const MovieMetaRow(
    this.movie, {
    super.key,
    this.showGenre = true,
    this.color = AppColors.textSecondary,
  });

  final Movie movie;
  final bool showGenre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color,
    );
    final dot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Text('•', style: style),
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${movie.year}', style: style),
        dot,
        RatingBadge(movie.ageRating),
        dot,
        Text(movie.duration, style: style),
        if (showGenre && movie.genres.isNotEmpty) ...[
          dot,
          Text(movie.primaryGenre, style: style),
        ],
      ],
    );
  }
}

/// Pill chip used for genres and filters.
class GenreChip extends StatelessWidget {
  const GenreChip(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceElevated,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.textPrimary : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textOnLight : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

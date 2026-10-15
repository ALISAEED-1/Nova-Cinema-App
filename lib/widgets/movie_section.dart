import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/responsive.dart';
import '../models/movie.dart';
import 'movie_card.dart';
import 'shimmer.dart';

/// Section heading with the brand's red accent bar and an optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Horizontally scrolling row of [MovieCard]s under a [SectionHeader].
class MovieSection extends StatelessWidget {
  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
    required this.onMovieTap,
    this.actionLabel,
    this.onAction,
    this.subtitleBuilder,
    this.progressBuilder,
    this.heroPrefix,
  });

  final String title;
  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? Function(Movie movie)? subtitleBuilder;
  final double? Function(Movie movie)? progressBuilder;

  /// When set, each card gets a Hero tag of `'$heroPrefix-${movie.id}'`.
  final String? heroPrefix;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final cardWidth = Responsive.of(context).cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          // Card art + two text lines.
          height: cardWidth * 9 / 16 + 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            physics: const BouncingScrollPhysics(),
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return MovieCard(
                movie: movie,
                width: cardWidth,
                subtitle: subtitleBuilder?.call(movie),
                progress: progressBuilder?.call(movie),
                heroTag: heroPrefix == null ? null : '$heroPrefix-${movie.id}',
                onTap: () => onMovieTap(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Skeleton row shown while the catalogue loads.
class MovieSectionSkeleton extends StatelessWidget {
  const MovieSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.of(context).cardWidth;
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: ShimmerBox(width: 160, height: 18, radius: 4),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: cardWidth * 9 / 16 + 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => MovieCardSkeleton(width: cardWidth),
            ),
          ),
        ],
      ),
    );
  }
}

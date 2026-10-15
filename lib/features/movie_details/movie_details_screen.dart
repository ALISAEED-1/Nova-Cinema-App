import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../widgets/app_image.dart';
import '../../widgets/movie_section.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rating_widget.dart';
import '../../widgets/watchlist_button.dart';
import '../home/catalog_controller.dart';
import '../player/playback_controller.dart';

class MovieDetailsScreen extends StatelessWidget {
  const MovieDetailsScreen({super.key, required this.movie, this.heroTag});

  final Movie movie;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final text = Theme.of(context).textTheme;
    final catalog = context.watch<CatalogController>();
    final progress = context.select<PlaybackController, double?>(
      (p) => p.progressFor(movie.id)?.isInProgress == true
          ? p.progressFor(movie.id)!.fraction
          : null,
    );
    final progressEntry = context.read<PlaybackController>().progressFor(movie.id);
    final similar = catalog.catalog?.similarTo(movie) ?? const <Movie>[];
    final expandedHeight = (responsive.height * 0.58).clamp(360.0, 640.0);

    Widget backdrop = AppImage(movie.imagePath, alignment: Alignment.topCenter);
    if (heroTag != null) backdrop = Hero(tag: heroTag!, child: backdrop);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            leadingWidth: 64,
            leading: Center(
              child: CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final collapsed = constraints.maxHeight <=
                    kToolbarHeight + MediaQuery.paddingOf(context).top + 8;
                return FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 64,
                    end: AppSpacing.lg,
                    bottom: 16,
                  ),
                  title: AnimatedOpacity(
                    duration: AppDurations.fast,
                    opacity: collapsed ? 1 : 0,
                    child: Text(
                      movie.title,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      backdrop,
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x80050608),
                              Colors.transparent,
                              Color(0xCC050608),
                              AppColors.background,
                            ],
                            stops: [0, 0.35, 0.8, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: responsive.contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie.tag != null) ...[
                        Text(movie.tag!, style: text.labelMedium),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(movie.title, style: text.displayMedium),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(child: MovieMetaRow(movie, showGenre: false)),
                          const _QualityBadge(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final g in movie.genres) GenreChip(g),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(movie.synopsis, style: text.bodyLarge),
                      const SizedBox(height: AppSpacing.xl),
                      _ActionButtons(
                        movie: movie,
                        progress: progress,
                        remainingLabel: progressEntry == null
                            ? null
                            : Formatters.minutesLeft(
                                progressEntry.position,
                                progressEntry.duration,
                              ),
                      ),
                      if (movie.storyline != null) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionLabel('Storyline'),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          movie.storyline!,
                          style: text.bodyMedium?.copyWith(height: 1.7),
                        ),
                      ],
                      if (movie.cast.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionLabel('Cast'),
                        const SizedBox(height: AppSpacing.md),
                        _CastRow(movie: movie),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionLabel('Details'),
                      const SizedBox(height: AppSpacing.md),
                      _DetailsTable(movie: movie),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (similar.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxl),
                child: MovieSection(
                  title: 'More Like This',
                  movies: similar,
                  heroPrefix: 'similar-${movie.id}',
                  onMovieTap: (m) => Navigator.of(context).pushReplacementNamed(
                    AppRoutes.details,
                    arguments: DetailsArgs(
                      movie: m,
                      heroTag: 'similar-${movie.id}-${m.id}',
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.movie,
    required this.progress,
    required this.remainingLabel,
  });

  final Movie movie;
  final double? progress;
  final String? remainingLabel;

  @override
  Widget build(BuildContext context) {
    final resuming = progress != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (movie.isPlayable) ...[
          PrimaryButton(
            label: resuming ? 'Resume' : 'Watch Now',
            icon: Icons.play_arrow_rounded,
            light: true,
            onPressed: () => context.openPlayer(movie),
          ),
          if (resuming) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceHighlight,
                    ),
                  ),
                ),
                if (remainingLabel != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    remainingLabel!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            if (movie.hasTrailer) ...[
              Expanded(
                child: SecondaryButton(
                  label: 'Trailer',
                  icon: Icons.movie_creation_outlined,
                  onPressed: () => context.openPlayer(movie, trailer: true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: WatchlistButton(movie: movie)),
          ],
        ),
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.circle, size: 7, color: AppColors.primary),
        SizedBox(width: 6),
        Text(
          '4K ULTRA HD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium,
    );
  }
}

class _CastRow extends StatelessWidget {
  const _CastRow({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: movie.cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, i) {
          final name = movie.cast[i];
          final image =
              i < movie.castImages.length ? movie.castImages[i] : null;
          return SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceElevated,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: image != null
                      ? AppImage(AssetPaths.image(image))
                      : Center(
                          child: Text(
                            Formatters.initials(name),
                            style: text.titleMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textPrimary, height: 1.2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (movie.director != null) ('Director', movie.director!),
      if (movie.cast.isNotEmpty) ('Cast', movie.cast.take(3).join(', ')),
      ('Genres', movie.genres.join(', ')),
      if (movie.mood != null) ('Mood', movie.mood!),
      ('Type', movie.type.label),
      ('Rating', movie.ageRating),
    ];
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(rows[i].$1, style: text.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

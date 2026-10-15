import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/movie.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/rating_widget.dart';
import '../../../widgets/watchlist_button.dart';

/// Full-bleed, auto-rotating hero carousel for featured titles.
class HeroBanner extends StatefulWidget {
  const HeroBanner({
    super.key,
    required this.movies,
    required this.onWatch,
    required this.onDetails,
    this.autoRotate = true,
  });

  final List<Movie> movies;
  final ValueChanged<Movie> onWatch;
  final ValueChanged<Movie> onDetails;
  final bool autoRotate;

  static String heroTag(Movie movie) => 'hero-${movie.id}';

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRotate != widget.autoRotate) _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!widget.autoRotate || widget.movies.length < 2) return;
    _timer = Timer(AppDurations.heroRotation, () {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.movies.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = Responsive.of(context).heroHeight;
    if (widget.movies.isEmpty) return SizedBox(height: height);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.movies.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _scheduleNext();
            },
            itemBuilder: (context, i) => _HeroPage(
              movie: widget.movies[i],
              onWatch: widget.onWatch,
              onDetails: widget.onDetails,
            ),
          ),
          if (widget.movies.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.movies.length; i++)
                    AnimatedContainer(
                      duration: AppDurations.normal,
                      curve: Curves.easeOut,
                      width: i == _page ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.primary
                            : AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(3),
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

class _HeroPage extends StatelessWidget {
  const _HeroPage({
    required this.movie,
    required this.onWatch,
    required this.onDetails,
  });

  final Movie movie;
  final ValueChanged<Movie> onWatch;
  final ValueChanged<Movie> onDetails;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final responsive = Responsive.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDetails(movie),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: HeroBanner.heroTag(movie),
            child: AppImage(
              movie.imagePath,
              alignment: Alignment.topCenter,
              fadeIn: false,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99050608),
                  Colors.transparent,
                  Color(0xB3050608),
                  AppColors.background,
                ],
                stops: [0, 0.3, 0.72, 1],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            bottom: AppSpacing.xxl,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: responsive.isTablet ? 560 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (movie.tag != null) ...[
                    Text(movie.tag!, style: text.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    movie.title.toUpperCase(),
                    style: responsive.isTablet
                        ? text.displayLarge?.copyWith(fontSize: 56)
                        : text.displayLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MovieMetaRow(movie, color: AppColors.textPrimary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    movie.synopsis,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Watch Now',
                          icon: Icons.play_arrow_rounded,
                          light: true,
                          onPressed: () => onWatch(movie),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      WatchlistButton(movie: movie, compact: true),
                      const SizedBox(width: AppSpacing.sm),
                      CircleIconButton(
                        icon: Icons.info_outline_rounded,
                        size: 48,
                        tooltip: 'More info',
                        onPressed: () => onDetails(movie),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero placeholder shown while the catalogue loads.
class HeroBannerSkeleton extends StatelessWidget {
  const HeroBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final height = Responsive.of(context).heroHeight;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.shimmerBase, AppColors.background],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(80, 12),
          const SizedBox(height: AppSpacing.md),
          _bar(240, 40),
          const SizedBox(height: AppSpacing.md),
          _bar(180, 14),
          const SizedBox(height: AppSpacing.md),
          _bar(double.infinity, 14),
          const SizedBox(height: AppSpacing.xl),
          _bar(double.infinity, 52),
        ],
      ),
    );
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerHighlight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../navigation/main_shell.dart';
import '../../widgets/movie_section.dart';
import '../../widgets/nova_logo.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/user_avatar.dart';
import '../player/playback_controller.dart';
import 'catalog_controller.dart';
import 'widgets/hero_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The bar only retracts once the page has travelled past this much, so a
  /// small bounce at the very top never flicks it away.
  static const double _hideAfter = 32;

  bool _showChrome = true;

  /// Slides the wordmark, search and avatar out of the way while the user is
  /// reading down the page, and brings them back the moment they head up.
  ///
  /// This tracks the per-frame delta rather than [UserScrollNotification]:
  /// that only fires once, as the drag begins, when the page is still pinned
  /// at zero — too early for the threshold below to allow a hide.
  bool _onScroll(ScrollNotification notification) {
    // Depth 0 is the page itself; the poster carousels and the hero pager are
    // nested viewports whose notifications bubble through here too.
    if (notification is! ScrollUpdateNotification ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final delta = notification.scrollDelta ?? 0;
    bool? next;
    if (notification.metrics.pixels <= _hideAfter) {
      next = true; // Resting near the top — the bar always belongs here.
    } else if (delta > 0.5) {
      next = false; // Travelling down the page.
    } else if (delta < -0.5) {
      next = true; // Heading back up.
    }

    if (next != null && next != _showChrome) {
      setState(() => _showChrome = next!);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final tabs = context.read<ShellTabs>();

    // Pause hero rotation while another tab is showing.
    final isVisible = context.select<ShellTabs, bool>(
      (t) => t.index == ShellTabs.home,
    );

    final Widget body = switch (catalog.state) {
      LoadState.idle || LoadState.loading => const _HomeSkeleton(),
      LoadState.error => AppErrorWidget(
          title: 'Couldn’t load the catalogue',
          message: catalog.errorMessage ?? 'Please try again.',
          onRetry: catalog.load,
        ),
      LoadState.ready => _HomeContent(
          catalog: catalog,
          heroAutoRotate: isVisible,
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: body,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // The wordmark leaves to the left, the actions to the
                      // right, so the bar parts in the middle.
                      _SlideAway(
                        visible: _showChrome,
                        towards: -1,
                        child: const NovaLogo(size: 22),
                      ),
                      const Spacer(),
                      _SlideAway(
                        visible: _showChrome,
                        towards: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleIconButton(
                              icon: Icons.search_rounded,
                              tooltip: 'Search',
                              onPressed: () => tabs.go(ShellTabs.search),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            UserAvatar(
                              size: 36,
                              onTap: () => tabs.go(ShellTabs.profile),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How long the top bar takes to clear the frame. Deliberately slower than
/// [AppDurations.normal] so the two halves read as a deliberate parting
/// rather than a flicker.
const Duration _chromeDuration = Duration(milliseconds: 520);

/// Carries one half of the top bar off the side of the screen — the wordmark
/// left, the search and avatar right — fading as it travels.
class _SlideAway extends StatelessWidget {
  const _SlideAway({
    required this.visible,
    required this.towards,
    required this.child,
  });

  final bool visible;

  /// -1 exits to the left, 1 to the right.
  final double towards;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      // The offset is a multiple of the child's own width; the extra 0.4
      // covers the gutter padding, which would otherwise leave an edge
      // peeking in at rest.
      offset: visible ? Offset.zero : Offset(1.4 * towards, 0),
      duration: _chromeDuration,
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _chromeDuration,
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.catalog, required this.heroAutoRotate});

  final CatalogController catalog;
  final bool heroAutoRotate;

  @override
  Widget build(BuildContext context) {
    final data = catalog.catalog!;
    final playback = context.watch<PlaybackController>();
    final continueWatching = playback.continueWatching
        .map((p) => catalog.byId(p.movieId))
        .whereType<Movie>()
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: HeroBanner(
            movies: data.heroMovies,
            autoRotate: heroAutoRotate,
            onWatch: (m) => context.openPlayer(m),
            onDetails: (m) =>
                context.openDetails(m, heroTag: HeroBanner.heroTag(m)),
          ),
        ),
        if (continueWatching.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: MovieSection(
                title: 'Continue Watching',
                movies: continueWatching,
                heroPrefix: 'continue',
                onMovieTap: (m) => context.openPlayer(m),
                progressBuilder: (m) => playback.progressFor(m.id)?.fraction,
                subtitleBuilder: (m) {
                  final p = playback.progressFor(m.id);
                  return p == null
                      ? null
                      : Formatters.minutesLeft(p.position, p.duration);
                },
              ),
            ),
          ),
        SliverList.builder(
          itemCount: data.sections.length,
          itemBuilder: (context, i) {
            final section = data.sections[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: MovieSection(
                title: section.title,
                movies: section.movies,
                heroPrefix: section.id,
                onMovieTap: (m) =>
                    context.openDetails(m, heroTag: '${section.id}-${m.id}'),
              ),
            );
          },
        ),
        SliverList.builder(
          itemCount: catalog.genreSections.length,
          itemBuilder: (context, i) {
            final section = catalog.genreSections[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: MovieSection(
                title: section.title,
                movies: section.movies,
                heroPrefix: section.id,
                onMovieTap: (m) =>
                    context.openDetails(m, heroTag: '${section.id}-${m.id}'),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 72 + bottomInset)),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          HeroBannerSkeleton(),
          SizedBox(height: AppSpacing.sm),
          MovieSectionSkeleton(),
          SizedBox(height: AppSpacing.xxl),
          MovieSectionSkeleton(),
          SizedBox(height: AppSpacing.xxl),
          MovieSectionSkeleton(),
        ],
      ),
    );
  }
}

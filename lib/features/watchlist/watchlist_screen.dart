import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../navigation/main_shell.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/state_widgets.dart';
import '../home/catalog_controller.dart';
import 'watchlist_controller.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final watchlist = context.watch<WatchlistController>();
    final text = Theme.of(context).textTheme;
    final movies = catalog.byIds(watchlist.ids);

    final Widget body = switch (catalog.state) {
      LoadState.idle || LoadState.loading => const LoadingWidget(),
      LoadState.error => AppErrorWidget(
          message: catalog.errorMessage ?? 'Please try again.',
          onRetry: catalog.load,
        ),
      LoadState.ready => movies.isEmpty
          ? EmptyStateWidget(
              icon: Icons.bookmark_add_outlined,
              title: 'Your list is empty',
              message:
                  'Save movies and series you want to watch and they’ll show up here.',
              actionLabel: 'Browse titles',
              onAction: () => context.read<ShellTabs>().go(ShellTabs.home),
            )
          : _WatchlistGrid(movies: movies),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('My List', style: text.headlineLarge),
                  const SizedBox(width: AppSpacing.md),
                  if (movies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '${movies.length} ${movies.length == 1 ? 'title' : 'titles'}',
                        style: text.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _WatchlistGrid extends StatelessWidget {
  const _WatchlistGrid({required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.of(context).gridColumns;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final width = constraints.maxWidth - AppSpacing.gutter * 2;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        final cellHeight = cellWidth * 9 / 16 + 48;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            80 + bottomInset,
          ),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: movies.length,
          itemBuilder: (context, i) {
            final movie = movies[i];
            return _WatchlistTile(movie: movie, width: cellWidth);
          },
        );
      },
    );
  }
}

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({required this.movie, required this.width});

  final Movie movie;
  final double width;

  Future<void> _showActions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(movie.title,
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${movie.year} • ${movie.genreLine}'),
            ),
            const Divider(),
            if (movie.isPlayable)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Watch now'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.openPlayer(movie);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('View details'),
              onTap: () {
                Navigator.of(sheet).pop();
                context.openDetails(movie, heroTag: 'watchlist-${movie.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined,
                  color: AppColors.error),
              title: const Text('Remove from My List',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.of(sheet).pop();
                _remove(context);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    await context.read<WatchlistController>().remove(movie.id);
    if (!context.mounted) return;
    showAppSnackBar(context, 'Removed from My List', icon: Icons.remove_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onLongPress: () => _showActions(context),
          child: MovieCard(
            movie: movie,
            width: width,
            heroTag: 'watchlist-${movie.id}',
            onTap: () =>
                context.openDetails(movie, heroTag: 'watchlist-${movie.id}'),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: AppColors.overlay,
            shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: 'Remove from My List',
              onPressed: () => _remove(context),
              iconSize: 16,
              color: Colors.white,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

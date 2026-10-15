import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../widgets/app_image.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/rating_widget.dart';
import '../../widgets/state_widgets.dart';
import '../home/catalog_controller.dart';
import 'search_view_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _applyTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    context.read<SearchViewModel>().commit(term);
    _focus.unfocus();
  }

  void _clear() {
    _controller.clear();
    context.read<SearchViewModel>().clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final catalogState = context.select<CatalogController, LoadState>(
      (c) => c.state,
    );
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: text.headlineLarge),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: vm.setQuery,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _applyTerm(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Titles, genres, people',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: vm.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clear,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            _FilterBar(vm: vm),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: switch (catalogState) {
                LoadState.idle || LoadState.loading =>
                  const LoadingWidget(message: 'Loading titles…'),
                LoadState.error => AppErrorWidget(
                    message: 'The catalogue is unavailable right now.',
                    onRetry: context.read<CatalogController>().load,
                  ),
                LoadState.ready => _Body(
                    vm: vm,
                    onRecentTap: _applyTerm,
                    onSuggestionTap: (m) => _applyTerm(m.title),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        physics: const BouncingScrollPhysics(),
        children: [
          GenreChip(
            'Movies',
            selected: vm.typeFilter == MediaType.movie,
            onTap: () => vm.setTypeFilter(MediaType.movie),
          ),
          const SizedBox(width: AppSpacing.sm),
          GenreChip(
            'Series',
            selected: vm.typeFilter == MediaType.series,
            onTap: () => vm.setTypeFilter(MediaType.series),
          ),
          if (vm.genres.isNotEmpty)
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 9,
              ),
              color: AppColors.borderStrong,
            ),
          for (final genre in vm.genres) ...[
            GenreChip(
              genre,
              selected: vm.genreFilter == genre,
              onTap: () => vm.setGenreFilter(genre),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.onRecentTap,
    required this.onSuggestionTap,
  });

  final SearchViewModel vm;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<Movie> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = vm.results;
    final suggestions = vm.suggestions;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final String heading;
    if (vm.hasQuery) {
      heading = 'Results for "${vm.query.trim()}"';
    } else if (vm.hasFilters) {
      heading = 'Filtered titles';
    } else {
      heading = 'Browse all titles';
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (suggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: _SuggestionList(
              movies: suggestions,
              onTap: onSuggestionTap,
            ),
          ),
        if (vm.isBrowsing && vm.recentSearches.isNotEmpty)
          SliverToBoxAdapter(
            child: _RecentSearches(
              terms: vm.recentSearches,
              onTap: onRecentTap,
              onRemove: vm.removeRecent,
              onClear: vm.clearRecent,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: Text(heading, style: text.titleMedium)),
                if (vm.isPending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text('${results.length}', style: text.bodySmall),
              ],
            ),
          ),
        ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'No titles found',
              message: vm.hasQuery
                  ? 'Nothing matches "${vm.query.trim()}". Try another title, genre or actor.'
                  : 'No titles match the selected filters.',
              actionLabel: vm.hasFilters ? 'Clear filters' : null,
              onAction: vm.hasFilters ? vm.clearFilters : null,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              80 + bottomInset,
            ),
            sliver: _ResultsGrid(movies: results),
          ),
      ],
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.of(context).gridColumns;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final cellWidth =
            (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
        // Art (16:9) plus two lines of text.
        final cellHeight = cellWidth * 9 / 16 + 48;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: AppSpacing.lg,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: movies.length,
          itemBuilder: (context, i) {
            final movie = movies[i];
            return MovieCard(
              movie: movie,
              width: cellWidth,
              heroTag: 'search-${movie.id}',
              onTap: () =>
                  context.openDetails(movie, heroTag: 'search-${movie.id}'),
            );
          },
        );
      },
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.movies, required this.onTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final movie in movies)
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 48,
                child: AppImage(
                  movie.imagePath,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              title: Text(movie.title, style: text.titleSmall),
              subtitle: Text(
                '${movie.year} • ${movie.type.label}',
                style: text.bodySmall,
              ),
              trailing: const Icon(Icons.north_west_rounded,
                  size: 16, color: AppColors.textMuted),
              onTap: () => onTap(movie),
            ),
        ],
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.terms,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> terms;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Recent searches', style: text.titleMedium)),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final term in terms)
                InputChip(
                  label: Text(term),
                  avatar: const Icon(Icons.history_rounded,
                      size: 16, color: AppColors.textMuted),
                  onPressed: () => onTap(term),
                  onDeleted: () => onRemove(term),
                  deleteIconColor: AppColors.textMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

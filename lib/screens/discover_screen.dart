import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_scope.dart';
import '../models/movie.dart';
import '../services/catalog.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/poster_card.dart';
import 'add_link_sheet.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Movie> _featured = const [];
  final List<Movie> _movies = [];
  MovieSource _source = MovieSource.archive;
  CatalogOption? _category;
  CatalogOption? _sort;
  String _query = '';
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  /// Bumped on every new search so stale responses are dropped.
  int _generation = 0;

  MovieCatalog get _catalog => AppScope.of(context).catalogFor(_source);
  CatalogOption get _currentCategory => _category ?? _catalog.categories.first;
  CatalogOption get _currentSort => _sort ?? _catalog.sorts.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeatured();
      _loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    final source = _source;
    try {
      final featured = await _catalog.featured();
      if (mounted && source == _source) setState(() => _featured = featured);
    } catch (_) {
      // The carousel is decorative; the grid shows any connection error.
    }
  }

  void _switchSource(MovieSource source) {
    if (source == _source) return;
    setState(() {
      _source = source;
      _category = null;
      _sort = null;
      _featured = const [];
    });
    _loadFeatured();
    _reload();
  }

  void _reload() {
    _generation++;
    setState(() {
      _movies.clear();
      _page = 0;
      _total = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _error != null) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await _catalog.search(
        query: _query,
        category: _currentCategory,
        sort: _currentSort,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final seen = _movies.map((m) => m.id).toSet();
      setState(() {
        _movies.addAll(page.movies.where((m) => seen.add(m.id)));
        _page = page.page;
        _total = page.total ?? _total;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(text));
    setState(() {}); // Toggle the clear button.
  }

  void _search(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q == _query) return;
    _query = q;
    _reload();
  }

  void _retry() {
    setState(() => _error = null);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Builder(
        builder: (context) {
          final hPad = context.gutter;
          final bottomInset = MediaQuery.paddingOf(context).bottom;

          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0 &&
                  n.metrics.axis == Axis.vertical &&
                  n.metrics.extentAfter < 900) {
                _loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surfaceHigh,
              onRefresh: () async {
                _loadFeatured();
                _reload();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        onAddLink: () => showAddLinkSheet(context),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 0),
                    sliver: SliverToBoxAdapter(child: _buildSearchField()),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SourceSwitcher(
                        selected: _source,
                        onChanged: _switchSource,
                      ),
                    ),
                  ),
                  if (_query.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 22),
                      sliver: SliverToBoxAdapter(
                        child: FeaturedCarousel(
                          key: ValueKey(_source),
                          movies: _featured,
                        ),
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterBarDelegate(
                      horizontalPadding: hPad,
                      categories: _catalog.categories,
                      category: _currentCategory,
                      sorts: _catalog.sorts,
                      sort: _currentSort,
                      onCategory: (c) {
                        if (c == _currentCategory) return;
                        _category = c;
                        _reload();
                      },
                      onSort: (s) {
                        if (s == _currentSort) return;
                        _sort = s;
                        _reload();
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 14),
                    sliver: SliverToBoxAdapter(child: _buildResultsLabel()),
                  ),
                  _buildGrid(hPad),
                  SliverToBoxAdapter(child: _buildFooter()),
                  SliverToBoxAdapter(child: SizedBox(height: bottomInset + 32)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onSubmitted: _search,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: switch (_source) {
          MovieSource.archive => 'Search 15,000+ classic films',
          MovieSource.commons => 'Search films on Wikimedia Commons',
        },
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textDim),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                onPressed: () {
                  _searchController.clear();
                  _search('');
                  setState(() {});
                },
              ),
      ),
    );
  }

  Widget _buildResultsLabel() {
    final String text;
    if (_query.isNotEmpty) {
      text = _total > 0
          ? '${formatCount(_total)} results for “$_query”'
          : 'Searching for “$_query”';
    } else {
      final noun = _total == 1 ? 'film' : 'films';
      text = _total > 0
          ? '${formatCount(_total)} $noun · ${_currentCategory.label}'
          : ' ';
    }
    return Text(
      text,
      style: const TextStyle(color: AppColors.textDim, fontSize: 13),
    );
  }

  Widget _buildGrid(double hPad) {
    if (_movies.isEmpty) {
      if (_error != null) {
        return SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Can\'t load movies',
            message: _error!,
            action: GradientButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: _retry,
            ),
          ),
        );
      }
      if (!_loading && !_hasMore) {
        return const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matches',
            message: 'Try another title, or pick a different category.',
          ),
        );
      }
    }

    final gridDelegate = _gridFor(context, hPad);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      sliver: _movies.isEmpty
          ? SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, i) => const _PosterSkeleton(),
                childCount: 12,
              ),
            )
          : SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, i) => PosterCard(
                  key: ValueKey(_movies[i].id),
                  movie: _movies[i],
                  onTap: () => openMovie(context, _movies[i]),
                ),
                childCount: _movies.length,
              ),
            ),
    );
  }

  /// Poster columns by screen width: 2 on tiny phones, 3 on phones, 4 on
  /// small tablets, then as many ~190pt posters as fit.
  SliverGridDelegate _gridFor(BuildContext context, double hPad) {
    const spacing = 16.0;
    final pageWidth = context.pageWidth;
    final width = pageWidth - hPad * 2;
    final columns = pageWidth < Breakpoints.smallPhone
        ? 2
        : pageWidth < 600
        ? 3
        : pageWidth < Breakpoints.rail
        ? 4
        : math.max(4, ((width + spacing) / (190 + spacing)).floor());
    final itemWidth = (width - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: 22,
      mainAxisExtent:
          itemWidth * 1.5 +
          PosterCard.captionHeight * math.max(1.0, context.textScale),
    );
  }

  Widget _buildFooter() {
    if (_movies.isEmpty) return const SizedBox.shrink();
    final Widget child;
    if (_error != null) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Couldn\'t load more.',
            style: TextStyle(color: AppColors.textDim),
          ),
          TextButton(onPressed: _retry, child: const Text('Retry')),
        ],
      );
    } else if (_loading) {
      child = const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (!_hasMore) {
      child = Text(
        'That\'s everything · ${_movies.length} films',
        style: const TextStyle(color: AppColors.textDim, fontSize: 13),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAddLink});
  final VoidCallback onAddLink;

  @override
  Widget build(BuildContext context) {
    final logo = context.rs(42);
    return Row(
      children: [
        Container(
          width: logo,
          height: logo,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(logo * 0.31),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: logo * 0.66,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText('CINEVAULT', style: displayStyle(context.rs(32))),
              const Text(
                'Free public‑domain classics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
              ),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.add_link_rounded,
          tooltip: 'Download from a link',
          onPressed: onAddLink,
        ),
      ],
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({
    required this.horizontalPadding,
    required this.categories,
    required this.category,
    required this.sorts,
    required this.sort,
    required this.onCategory,
    required this.onSort,
  });

  final double horizontalPadding;
  final List<CatalogOption> categories;
  final CatalogOption category;
  final List<CatalogOption> sorts;
  final CatalogOption sort;
  final ValueChanged<CatalogOption> onCategory;
  final ValueChanged<CatalogOption> onSort;

  static const _height = 64.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.category != category ||
      old.sort != sort ||
      !identical(old.categories, categories) ||
      old.horizontalPadding != horizontalPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: AppColors.bg.withValues(
            alpha: overlapsContent || shrinkOffset > 0 ? 0.85 : 1,
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  key: ValueKey(categories),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 14, 8, 14),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    return _CategoryChip(
                      label: c.label,
                      selected: c == category,
                      onTap: () => onCategory(c),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: horizontalPadding - 8),
                child: PopupMenuButton<CatalogOption>(
                  tooltip: 'Sort',
                  initialValue: sort,
                  onSelected: onSort,
                  icon: const Icon(Icons.tune_rounded, color: AppColors.text),
                  itemBuilder: (context) => [
                    for (final s in sorts)
                      PopupMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(
                              s == sort
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 18,
                              color: s == sort
                                  ? AppColors.accent
                                  : AppColors.textDim,
                            ),
                            const SizedBox(width: 10),
                            Text(s.label),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.gradient : null,
            color: selected ? null : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceSwitcher extends StatelessWidget {
  const _SourceSwitcher({required this.selected, required this.onChanged});
  final MovieSource selected;
  final ValueChanged<MovieSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          for (final source in MovieSource.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: source == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(source),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 40,
                    decoration: BoxDecoration(
                      color: source == selected
                          ? AppColors.surfaceHigh
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: source == selected
                            ? AppColors.accent.withValues(alpha: 0.45)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          switch (source) {
                            MovieSource.archive =>
                              Icons.account_balance_rounded,
                            MovieSource.commons => Icons.public_rounded,
                          },
                          size: 17,
                          color: source == selected
                              ? AppColors.accent2
                              : AppColors.textDim,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            context.pageWidth < 380
                                ? source.shortLabel
                                : source.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: source == selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: source == selected
                                  ? AppColors.text
                                  : AppColors.textDim,
                            ),
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

class _PosterSkeleton extends StatelessWidget {
  const _PosterSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 2 / 3, child: Shimmer(radius: 16)),
        SizedBox(height: 10),
        Shimmer(height: 12, width: 110, radius: 6),
        SizedBox(height: 6),
        Shimmer(height: 10, width: 70, radius: 5),
      ],
    );
  }
}

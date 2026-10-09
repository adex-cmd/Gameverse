import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../actions.dart';
import '../models/movie.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/responsive.dart';
import 'common.dart';

class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.movies});

  final List<Movie> movies;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  PageController? _controller;
  double? _fraction;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final c = _controller;
      if (c == null || !c.hasClients || widget.movies.length < 2) return;
      c.animateToPage(
        (_index + 1) % widget.movies.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isTablet;
    final gutter = context.gutter;
    // Tablets: a share of the screen height. Phones: a scaled design height.
    // Both grow a little when the user has large system fonts.
    final fontGrowth = 1 + math.max(0, context.textScale - 1) * 0.5;
    final height =
        (wide
            ? (context.screen.height * 0.42).clamp(300.0, 380.0)
            : context.rs(236)) *
        fontGrowth;
    final fraction = wide ? 1.0 : 0.9;
    final pagePad = wide ? gutter : 6.0;

    if (widget.movies.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Shimmer(height: height, radius: 24),
      );
    }

    if (_fraction != fraction) {
      _controller?.dispose();
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: _index,
      );
      _fraction = fraction;
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            padEnds: wide,
            itemCount: widget.movies.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _restartTimer();
            },
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 && !wide ? gutter : pagePad,
                right: pagePad,
              ),
              child: _FeaturedCard(movie: widget.movies[i], wide: wide),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.movies.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: i == _index ? AppColors.gradient : null,
                  color: i == _index ? null : Colors.white24,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.movie, required this.wide});
  final Movie movie;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openMovie(context, movie),
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final padding = wide ? 28.0 : context.rs(16);
    // On phones the poster is capped to about a third of the card so the
    // title and button always have room, even on a 320pt-wide screen.
    final posterMaxWidth = wide
        ? double.infinity
        : context.pageWidth * 0.9 * 0.34;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Transform.scale(
              scale: 1.35,
              child: NetworkPoster(movie.posterUrl),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xF208080E),
                  Color(0xB308080E),
                  Color(0x4D08080E),
                ],
              ),
            ),
          ),
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: posterMaxWidth),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: NetworkPoster(movie.posterUrl),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: wide ? 28 : context.rs(14)),
                Expanded(
                  child: wide ? _wideText(context) : _phoneText(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label() => const FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: GradientText(
      'FEATURED CLASSIC',
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _phoneText(BuildContext context) {
    final meta = [?movie.year, ?movie.runtime].join('  ·  ');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(),
        const SizedBox(height: 6),
        Text(
          movie.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: displayStyle(context.rs(30)),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 12),
        GradientButton(
          label: 'Download',
          icon: Icons.download_rounded,
          height: context.rs(40),
          dense: true,
          onPressed: () => downloadMovie(context, movie),
        ),
      ],
    );
  }

  Widget _wideText(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(),
        const SizedBox(height: 6),
        Text(
          movie.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: displayStyle(context.rs(44)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (movie.year != null) Pill(movie.year!),
            if (movie.runtime != null)
              Pill(movie.runtime!, icon: Icons.schedule_rounded),
            if (movie.downloads > 0)
              Pill(
                '${formatCount(movie.downloads)} downloads',
                icon: Icons.trending_up_rounded,
              ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            GradientButton(
              label: 'Download',
              icon: Icons.download_rounded,
              height: 48,
              onPressed: () => downloadMovie(context, movie),
            ),
            GhostButton(
              label: 'Details',
              icon: Icons.info_outline_rounded,
              height: 48,
              onPressed: () => openMovie(context, movie),
            ),
          ],
        ),
      ],
    );
  }
}

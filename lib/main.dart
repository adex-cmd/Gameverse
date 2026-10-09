import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_scope.dart';
import 'models/movie.dart';
import 'screens/add_link_sheet.dart';
import 'screens/discover_screen.dart';
import 'screens/downloads_screen.dart';
import 'services/archive_api.dart';
import 'services/catalog.dart';
import 'services/commons_api.dart';
import 'services/download_manager.dart';
import 'theme.dart';
import 'utils/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final downloads = DownloadManager();
  await downloads.init();
  final client = http.Client();
  runApp(
    CineVaultApp(
      catalogs: {
        MovieSource.archive: ArchiveApi(client: client),
        MovieSource.commons: CommonsApi(client: client),
      },
      downloads: downloads,
    ),
  );
}

class CineVaultApp extends StatefulWidget {
  const CineVaultApp({
    super.key,
    required this.catalogs,
    required this.downloads,
  });

  final Map<MovieSource, MovieCatalog> catalogs;
  final DownloadManager downloads;

  @override
  State<CineVaultApp> createState() => _CineVaultAppState();
}

class _CineVaultAppState extends State<CineVaultApp> {
  final _tab = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      catalogs: widget.catalogs,
      downloads: widget.downloads,
      tab: _tab,
      child: MaterialApp(
        title: 'CineVault',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Every screen sits under this MediaQuery. It passes the device's real
        // size and insets through, but keeps the system font setting within a
        // range the layouts are designed for.
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child!,
          );
        },
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: scope.tab,
      builder: (context, index, _) {
        final wide = context.hasRail;
        return PopScope(
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) scope.tab.value = 0;
          },
          child: Scaffold(
            extendBody: true,
            body: Row(
              children: [
                if (wide) ...[
                  _SideNav(index: index),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.stroke,
                  ),
                ],
                Expanded(
                  key: const ValueKey('pages'),
                  child: IndexedStack(
                    index: index,
                    children: const [DiscoverScreen(), DownloadsScreen()],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: wide ? null : _BottomNav(index: index),
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: context.rs(70),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore_rounded,
                      label: 'Discover',
                      selected: index == 0,
                      onTap: () => scope.tab.value = 0,
                    ),
                  ),
                  _AddButton(onTap: () => showAddLinkSheet(context)),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.download_outlined,
                      selectedIcon: Icons.download_rounded,
                      label: 'Downloads',
                      selected: index == 1,
                      showBadge: true,
                      onTap: () => scope.tab.value = 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return SizedBox(
      width:
          Breakpoints.railWidth -
          1, // The divider beside it takes the last pixel.
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 24),
            _AddButton(onTap: () => showAddLinkSheet(context)),
            const SizedBox(height: 28),
            SizedBox(
              height: 64,
              child: _NavItem(
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
                label: 'Discover',
                selected: index == 0,
                onTap: () => scope.tab.value = 0,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: _NavItem(
                icon: Icons.download_outlined,
                selectedIcon: Icons.download_rounded,
                label: 'Downloads',
                selected: index == 1,
                showBadge: true,
                onTap: () => scope.tab.value = 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    Widget iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: context.rs(26),
      color: Colors.white,
    );
    if (showBadge) {
      iconWidget = ListenableBuilder(
        listenable: downloads,
        builder: (context, child) {
          final count = downloads.activeCount;
          return Badge(
            isLabelVisible: count > 0,
            backgroundColor: AppColors.accent,
            label: Text('$count'),
            child: child,
          );
        },
        child: iconWidget,
      );
    }
    final color = selected ? Colors.white : AppColors.textDim;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            selected
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => AppColors.gradient.createShader(r),
                    child: iconWidget,
                  )
                : ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.textDim,
                      BlendMode.srcIn,
                    ),
                    child: iconWidget,
                  ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Download from a link',
      child: Container(
        width: context.rs(54),
        height: context.rs(54),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.gradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: context.rs(30),
            ),
          ),
        ),
      ),
    );
  }
}

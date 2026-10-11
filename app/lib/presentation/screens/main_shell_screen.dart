import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/mini_player_bar.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'search_screen.dart';
import 'settings_profile_screen.dart';

/// Persistent application shell hosting the 5 primary tabs:
/// 0: Home, 1: Search, 2: Library, 3: Downloads, 4: Settings/Profile,
/// along with the floating glassmorphic [MiniPlayerBar] and blurred bottom navigation bar.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({
    super.key,
    this.navigationShell,
    this.initialTabIndex = 0,
  });

  final StatefulNavigationShell? navigationShell;
  final int initialTabIndex;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late int _fallbackIndex;

  static const List<_NavTabItem> _tabs = <_NavTabItem>[
    _NavTabItem(
      label: 'Home',
      icon: LucideIcons.home,
      route: '/home',
    ),
    _NavTabItem(
      label: 'Search',
      icon: LucideIcons.search,
      route: '/search',
    ),
    _NavTabItem(
      label: 'Library',
      icon: LucideIcons.library,
      route: '/library',
    ),
    _NavTabItem(
      label: 'Downloads',
      icon: LucideIcons.downloadCloud,
      route: '/downloads',
    ),
    _NavTabItem(
      label: 'Profile',
      icon: LucideIcons.user,
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fallbackIndex = widget.initialTabIndex;
  }

  int get _currentIndex =>
      widget.navigationShell?.currentIndex ?? _fallbackIndex;

  void _onSelectTab(int index) {
    HapticFeedback.selectionClick();
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
    } else {
      setState(() => _fallbackIndex = index);
    }
  }

  void _openNowPlayingModal(BuildContext context) {
    try {
      context.push('/now-playing');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const NowPlayingScreen(),
        ),
      );
    }
  }

  Widget _buildActiveFallbackBody(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const SearchScreen();
      case 2:
        return const LibraryScreen();
      case 3:
        return const DownloadsScreen();
      case 4:
        return const SettingsProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DownloadsState downloadsState = ref.watch(downloadsProvider);
    final int activeDownloadCount = downloadsState.activeTasks.length;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: widget.navigationShell ??
                IndexedStack(
                  index: _currentIndex,
                  children: <Widget>[
                    _buildActiveFallbackBody(0),
                    _buildActiveFallbackBody(1),
                    _buildActiveFallbackBody(2),
                    _buildActiveFallbackBody(3),
                    _buildActiveFallbackBody(4),
                  ],
                ),
          ),

          // Floating Mini-Player + Blurred Glass Bottom Navigation Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MiniPlayerBar(
                  onExpandNowPlaying: () => _openNowPlayingModal(context),
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AnniTheme.surface1.withOpacity(0.84),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.09),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List<Widget>.generate(_tabs.length, (int i) {
                              final _NavTabItem item = _tabs[i];
                              final bool isSelected = _currentIndex == i;
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onSelectTab(i),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: <Widget>[
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              gradient: isSelected
                                                  ? LinearGradient(
                                                      colors: <Color>[
                                                        AnniTheme.accentViolet
                                                            .withOpacity(0.28),
                                                        AnniTheme.accentMagenta
                                                            .withOpacity(0.22),
                                                      ],
                                                    )
                                                  : null,
                                            ),
                                            child: Icon(
                                              item.icon,
                                              size: 21,
                                              color: isSelected
                                                  ? AnniTheme.accentMagenta
                                                  : AnniTheme.textSecondary,
                                            ),
                                          ),
                                          if (i == 3 && activeDownloadCount > 0)
                                            Positioned(
                                              right: 2,
                                              top: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: AnniTheme.accentOrange,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$activeDownloadCount',
                                                  style: GoogleFonts.jetBrainsMono(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AnniTheme.textPrimary
                                              : AnniTheme.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
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

class _NavTabItem {
  const _NavTabItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

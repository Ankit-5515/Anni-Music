import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/anni_logo_widget.dart';
import '../widgets/glass_components.dart';
import 'detail_screens.dart';
import 'equalizer_screen.dart';
import 'now_playing_screen.dart';

/// Home discovery & quick-access dashboard for Anni Music.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;
  String _selectedCategory = 'All';

  static const List<String> _categories = <String>[
    'All',
    'Bollywood',
    'Hindi',
    'Punjabi',
    'Tamil',
    'Telugu',
    'Lo-Fi',
    'Electronic',
    'Classical',
  ];

  String _getGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _triggerCloudSync() async {
    setState(() => _isSyncing = true);
    HapticFeedback.lightImpact();
    try {
      await ref.read(musicRepositoryProvider).syncWithCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud delta sync complete — playlists & settings up to date.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authStateProvider);
    final UserSettingsEntity settings = ref.watch(userSettingsProvider);
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final List<Track> recentTracks = ref.watch(recentlyPlayedProvider);
    final AsyncValue<List<Track>> recommendationsAsync =
        ref.watch(recommendationsProvider);
    final AsyncValue<List<Track>> trendingAsync =
        ref.watch(trendingTracksProvider(null));
    final List<Playlist> playlists = ref.watch(playlistsProvider);
    final DownloadsState downloadsState = ref.watch(downloadsProvider);

    final String firstName = authState.user.displayName.split(' ').first;
    final Track featuredTrack = kSeededLegalCatalog.first;

    // Group unique top artists from catalog
    final Map<String, Track> artistSamples = <String, Track>{};
    for (final Track t in kSeededLegalCatalog) {
      artistSamples.putIfAbsent(t.artist, () => t);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AnniTheme.subtleAuroraGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              // 1. Top Greeting Bar + Sync Status Pill + Equalizer Shortcut
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: <Widget>[
                      const AnniLogoWidget(size: 40, animate: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_getGreeting()}, $firstName',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: AnniTheme.textPrimary,
                              ),
                            ),
                            Row(
                              children: <Widget>[
                                Icon(
                                  settings.offlineMode
                                      ? LucideIcons.wifiOff
                                      : LucideIcons.cloud,
                                  size: 12,
                                  color: settings.offlineMode
                                      ? AnniTheme.warning
                                      : AnniTheme.success,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  settings.offlineMode
                                      ? 'Offline Mode Active'
                                      : (authState.user.isGuest
                                          ? 'Local Hybrid Mode'
                                          : 'Cloud Synced • Lossless Ready'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AnniTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Sync Pill Button
                      GestureDetector(
                        onTap: _isSyncing ? null : _triggerCloudSync,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AnniTheme.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AnniTheme.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _isSyncing
                                    ? LucideIcons.loader
                                    : LucideIcons.refreshCw,
                                size: 13,
                                color: AnniTheme.accentViolet,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isSyncing ? 'Syncing' : 'Sync',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AnniTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Studio Equalizer',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EqualizerScreen(),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AnniTheme.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AnniTheme.glassBorder),
                          ),
                          child: const Icon(
                            LucideIcons.sliders,
                            size: 18,
                            color: AnniTheme.accentMagenta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Quick-Access 2x2 Grid (Liked Songs, Mixes, Local Hi-Res, Studio EQ)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      _QuickAccessTile(
                        title: 'Liked Songs',
                        subtitle: '${ref.watch(favoritesProvider).length} tracks',
                        icon: LucideIcons.heart,
                        accent: AnniTheme.accentMagenta,
                        onTap: () {
                          final List<Track> favs = ref.read(favoritesProvider);
                          final List<Track> list =
                              favs.isNotEmpty ? favs : kSeededLegalCatalog;
                          ref
                              .read(playbackStateProvider.notifier)
                              .playTrack(list.first, queue: list);
                        },
                      ),
                      _QuickAccessTile(
                        title: 'Obsidian Mix',
                        subtitle: 'FLAC 24-bit',
                        icon: LucideIcons.sparkles,
                        accent: AnniTheme.accentViolet,
                        onTap: () {
                          if (playlists.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PlaylistDetailScreen(
                                  playlist: playlists.first,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _QuickAccessTile(
                        title: 'On-Device Audio',
                        subtitle:
                            '${ref.watch(localLibraryProvider).tracks.length} local',
                        icon: LucideIcons.hardDrive,
                        accent: AnniTheme.success,
                        onTap: () {
                          final List<Track> local =
                              ref.read(localLibraryProvider).tracks;
                          if (local.isNotEmpty) {
                            ref
                                .read(playbackStateProvider.notifier)
                                .playTrack(local.first, queue: local);
                          }
                        },
                      ),
                      _QuickAccessTile(
                        title: '10-Band Studio EQ',
                        subtitle: ref.watch(equalizerProvider).currentPreset,
                        icon: LucideIcons.sliders,
                        accent: AnniTheme.accentOrange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EqualizerScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Category Filter Chips (Indian Genres & Lossless)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int idx) {
                      final String cat = _categories[idx];
                      final bool isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AnniTheme.textSecondary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AnniTheme.accentViolet,
                        backgroundColor: AnniTheme.surface1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        onSelected: (bool selected) {
                          if (selected) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),

              // Filtered Category Section (if specific category selected)
              if (_selectedCategory != 'All') ...<Widget>[
                _buildSectionHeader(
                  title: 'Top in $_selectedCategory',
                  subtitle: 'Curated authorized tracks and regional hits',
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final List<Track> categoryTracks = kSeededLegalCatalog
                          .where((Track t) =>
                              t.genre.toLowerCase().contains(_selectedCategory.toLowerCase()))
                          .toList();
                      if (categoryTracks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Text(
                            'No tracks found in $_selectedCategory',
                            style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary),
                          ),
                        );
                      }
                      final Track track = categoryTracks[index];
                      return AnniTrackTile(
                        track: track,
                        isPlaying: playback.currentTrack?.id == track.id && playback.isPlaying,
                        onTap: () {
                          ref
                              .read(playbackStateProvider.notifier)
                              .playTrack(track, queue: categoryTracks);
                        },
                      );
                    },
                    childCount: kSeededLegalCatalog
                        .where((Track t) =>
                            t.genre.toLowerCase().contains(_selectedCategory.toLowerCase()))
                        .length
                        .clamp(0, 10),
                  ),
                ),
              ],

              // 3. Featured Hero Card with Gradient CTA
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF28194B),
                          Color(0xFF3A1434),
                          Color(0xFF171324),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AnniTheme.accentViolet.withOpacity(0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const QualityBadge(label: 'FLAC 24-BIT MASTER'),
                                  const SizedBox(width: 8),
                                  Text(
                                    'FEATURED PREMIERE',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AnniTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                featuredTrack.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${featuredTrack.artist} • ${featuredTrack.album}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: Colors.white.withOpacity(0.78),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: <Widget>[
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AnniTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        ref
                                            .read(playbackStateProvider.notifier)
                                            .playTrack(
                                              featuredTrack,
                                              queue: kSeededLegalCatalog,
                                            );
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            fullscreenDialog: true,
                                            builder: (_) =>
                                                const NowPlayingScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        LucideIcons.play,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        'Listen Now',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    tooltip: 'Download Lossless',
                                    onPressed: () {
                                      ref
                                          .read(downloadsProvider.notifier)
                                          .enqueueDownload(featuredTrack);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Queued "${featuredTrack.title}" for offline FLAC download.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.download,
                                        size: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        AnniArtworkWidget(
                          artworkUrl: featuredTrack.artworkUrl,
                          dominantHex: featuredTrack.dominantColor,
                          size: 108,
                          borderRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Carousel: Recently Played
              _buildSectionHeader(
                title: 'Recently Played',
                subtitle: 'Jump back into your active sessions',
                actionLabel: 'Play All',
                onAction: () {
                  if (recentTracks.isNotEmpty) {
                    ref
                        .read(playbackStateProvider.notifier)
                        .playTrack(recentTracks.first, queue: recentTracks);
                  }
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 215,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: recentTracks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (BuildContext context, int index) {
                      final Track track = recentTracks[index];
                      return _TrackCarouselCard(
                        track: track,
                        isPlaying: playback.currentTrack?.id == track.id &&
                            playback.isPlaying,
                        onTap: () {
                          ref
                              .read(playbackStateProvider.notifier)
                              .playTrack(track, queue: recentTracks);
                        },
                      );
                    },
                  ),
                ),
              ),

              // 5. Carousel: Made For You (Daily Mixes / Curated Playlists)
              _buildSectionHeader(
                title: 'Made For You',
                subtitle: 'Daily hybrid mixes blending local & legal FLAC streams',
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (BuildContext context, int index) {
                      final Playlist pl = playlists[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlaylistDetailScreen(playlist: pl),
                            ),
                          );
                        },
                        child: Container(
                          width: 165,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AnniTheme.surface1,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AnniTheme.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              AnniArtworkWidget(
                                artworkUrl: pl.effectiveCoverUrl,
                                size: 112,
                                borderRadius: 14,
                              ),
                              const Spacer(),
                              Text(
                                pl.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AnniTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${pl.trackCount} tracks • ${pl.formattedTotalDuration}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 6. Carousel: Trending Legal Streams
              _buildSectionHeader(
                title: 'Trending Legal Streams',
                subtitle: 'Creative Commons & Public Domain masters',
              ),
              SliverToBoxAdapter(
                child: trendingAsync.when(
                  loading: () => SizedBox(
                    height: 215,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, __) => const AnniShimmerBox(
                        width: 154,
                        height: 205,
                        borderRadius: 18,
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (List<Track> tracks) => SizedBox(
                    height: 215,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tracks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (BuildContext context, int index) {
                        final Track track = tracks[index];
                        return _TrackCarouselCard(
                          track: track,
                          isPlaying: playback.currentTrack?.id == track.id &&
                              playback.isPlaying,
                          onTap: () {
                            ref
                                .read(playbackStateProvider.notifier)
                                .playTrack(track, queue: tracks);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 7. Carousel: Top Artists
              _buildSectionHeader(
                title: 'Top Artists',
                subtitle: 'Independent & classical creators across your library',
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 138,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: artistSamples.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (BuildContext context, int idx) {
                      final String artistName = artistSamples.keys.elementAt(idx);
                      final Track sampleTrack = artistSamples[artistName]!;
                      final List<Track> artistTracks = kSeededLegalCatalog
                          .where((Track t) => t.artist == artistName)
                          .toList();

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ArtistDetailScreen(
                                artistName: artistName,
                                tracks: artistTracks,
                              ),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 96,
                          child: Column(
                            children: <Widget>[
                              AnniArtworkWidget(
                                artworkUrl: sampleTrack.artworkUrl,
                                dominantHex: sampleTrack.dominantColor,
                                size: 84,
                                borderRadius: 42,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AnniTheme.textPrimary,
                                ),
                              ),
                              Text(
                                sampleTrack.genre,
                                maxLines: 1,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AnniTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 8. Section: New Downloads & Recommendations List
              _buildSectionHeader(
                title: downloadsState.completedTasks.isNotEmpty
                    ? 'New Downloads (Offline Ready)'
                    : 'Recommended For Your Ears',
                subtitle: downloadsState.completedTasks.isNotEmpty
                    ? '${downloadsState.completedTasks.length} tracks cached on device'
                    : 'Curated by acoustic profile & listening history',
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 165),
                sliver: recommendationsAsync.when(
                  loading: () => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: AnniShimmerBox(width: double.infinity, height: 64),
                      ),
                      childCount: 4,
                    ),
                  ),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  data: (List<Track> recs) {
                    final List<Track> displayList =
                        downloadsState.completedTasks.isNotEmpty
                            ? downloadsState.completedTasks
                                .map((DownloadTaskItem d) => d.track)
                                .toList()
                            : recs.take(6).toList();
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final Track track = displayList[index];
                          return AnniTrackTile(
                            track: track,
                            isPlaying: playback.currentTrack?.id == track.id &&
                                playback.isPlaying,
                            onTap: () {
                              ref
                                  .read(playbackStateProvider.notifier)
                                  .playTrack(track, queue: displayList);
                            },
                            onFavoriteToggle: () {
                              ref
                                  .read(favoritesProvider.notifier)
                                  .toggleFavorite(track);
                            },
                            onDownloadTap: () {
                              ref
                                  .read(downloadsProvider.notifier)
                                  .enqueueDownload(track);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Downloading "${track.title}"...',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: displayList.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AnniTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AnniTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnniTheme.accentMagenta,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AnniTheme.surface1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AnniTheme.glassBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnniTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      color: AnniTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackCarouselCard extends StatelessWidget {
  const _TrackCarouselCard({
    required this.track,
    required this.isPlaying,
    required this.onTap,
  });

  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 154,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AnniTheme.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPlaying ? AnniTheme.accentMagenta : AnniTheme.glassBorder,
            width: isPlaying ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AnniArtworkWidget(
                  artworkUrl: track.artworkUrl,
                  dominantHex: track.dominantColor,
                  size: 134,
                  borderRadius: 14,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: QualityBadge(label: track.qualityBadge, compact: true),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AnniTheme.primaryGradient,
                    ),
                    child: Icon(
                      isPlaying ? LucideIcons.pause : LucideIcons.play,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AnniTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AnniTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

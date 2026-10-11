import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';

/// Unified Hybrid Search screen querying Local Storage, Jamendo CC, Internet Archive,
/// and Official YouTube IFrame sessions with instant debounce, source filters, and Genre tiles.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();

  static const List<_GenreTileData> _genres = <_GenreTileData>[
    _GenreTileData(
      name: 'Synthwave',
      subtitle: 'Retro-Futuristic Analog',
      colorA: Color(0xFF8B5CF6),
      colorB: Color(0xFFEC4899),
      icon: LucideIcons.sparkles,
    ),
    _GenreTileData(
      name: 'Lo-Fi',
      subtitle: 'Late Night Study Beats',
      colorA: Color(0xFFEC4899),
      colorB: Color(0xFFF59E0B),
      icon: LucideIcons.coffee,
    ),
    _GenreTileData(
      name: 'Ambient',
      subtitle: 'Atmospheric Soundscapes',
      colorA: Color(0xFF0EA5E9),
      colorB: Color(0xFF6366F1),
      icon: LucideIcons.cloudRain,
    ),
    _GenreTileData(
      name: 'Electronic',
      subtitle: 'Club & Modular Bass',
      colorA: Color(0xFF10B981),
      colorB: Color(0xFF059669),
      icon: LucideIcons.zap,
    ),
    _GenreTileData(
      name: 'Classical',
      subtitle: 'Public Domain Masters',
      colorA: Color(0xFFF59E0B),
      colorB: Color(0xFFD97706),
      icon: LucideIcons.music2,
    ),
    _GenreTileData(
      name: 'Indie',
      subtitle: 'Acoustic & Dream Pop',
      colorA: Color(0xFF6366F1),
      colorB: Color(0xFFA855F7),
      icon: LucideIcons.guitar,
    ),
    _GenreTileData(
      name: 'Rock',
      subtitle: 'Overdrive & Post-Rock',
      colorA: Color(0xFFEF4444),
      colorB: Color(0xFFB91C1C),
      icon: LucideIcons.flame,
    ),
    _GenreTileData(
      name: 'All',
      subtitle: 'Full Hybrid Catalog',
      colorA: Color(0xFF3B82F6),
      colorB: Color(0xFF8B5CF6),
      icon: LucideIcons.compass,
    ),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchState searchState = ref.watch(searchStateProvider);
    final SearchStateNotifier notifier = ref.read(searchStateProvider.notifier);
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            // 1. Header & Instant Debounced Search Input
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hybrid Search',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AnniTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search across local device files, Jamendo CC, Internet Archive & YouTube',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AnniTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _queryController,
                      onChanged: notifier.onQueryChanged,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: AnniTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Songs, artists, FLAC albums, or genres...',
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 19,
                          color: AnniTheme.accentMagenta,
                        ),
                        suffixIcon: _queryController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _queryController.clear();
                                  notifier.onQueryChanged('');
                                  setState(() {});
                                },
                                icon: const Icon(LucideIcons.x, size: 17),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Source Provider Filter Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: <Widget>[
                    _buildSourceFilterChip(
                      label: 'All Sources',
                      selected: searchState.sourceFilter == null,
                      onTap: () => notifier.setSourceFilter(null),
                    ),
                    const SizedBox(width: 8),
                    _buildSourceFilterChip(
                      label: 'Local Device',
                      selected: searchState.sourceFilter == TrackSource.local,
                      onTap: () => notifier.setSourceFilter(TrackSource.local),
                    ),
                    const SizedBox(width: 8),
                    _buildSourceFilterChip(
                      label: 'Jamendo CC',
                      selected: searchState.sourceFilter == TrackSource.jamendo,
                      onTap: () => notifier.setSourceFilter(TrackSource.jamendo),
                    ),
                    const SizedBox(width: 8),
                    _buildSourceFilterChip(
                      label: 'Internet Archive',
                      selected:
                          searchState.sourceFilter == TrackSource.internetArchive,
                      onTap: () =>
                          notifier.setSourceFilter(TrackSource.internetArchive),
                    ),
                    const SizedBox(width: 8),
                    _buildSourceFilterChip(
                      label: 'YouTube IFrame',
                      selected: searchState.sourceFilter == TrackSource.youtube,
                      onTap: () => notifier.setSourceFilter(TrackSource.youtube),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Recent Searches (with Clear button)
            if (searchState.recentSearches.isNotEmpty &&
                searchState.query.trim().isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Recent Searches',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AnniTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: notifier.clearRecentSearches,
                            child: Text(
                              'Clear',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: searchState.recentSearches.map((String term) {
                          return ActionChip(
                            backgroundColor: AnniTheme.surface2,
                            side: const BorderSide(color: AnniTheme.glassBorder),
                            avatar: const Icon(
                              LucideIcons.clock,
                              size: 13,
                              color: AnniTheme.textSecondary,
                            ),
                            label: Text(
                              term,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: AnniTheme.textPrimary,
                              ),
                            ),
                            onPressed: () {
                              _queryController.text = term;
                              notifier.onQueryChanged(term);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Rich Visual Genre Tiles when query is empty
            if (searchState.query.trim().isEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'Browse Genres & Moods',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AnniTheme.textPrimary,
                        ),
                      ),
                      if (searchState.selectedGenre != 'All') ...<Widget>[
                        const Spacer(),
                        QualityBadge(label: 'Genre: ${searchState.selectedGenre}'),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.25,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final _GenreTileData g = _genres[index];
                      final bool isSelected =
                          searchState.selectedGenre.toLowerCase() ==
                              g.name.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setGenreFilter(g.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                g.colorA.withOpacity(isSelected ? 0.92 : 0.65),
                                g.colorB.withOpacity(isSelected ? 0.88 : 0.45),
                              ],
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.14),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      g.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      g.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.84),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                g.icon,
                                size: 24,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _genres.length,
                  ),
                ),
              ),
            ],

            // 5. Live Search Results Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: <Widget>[
                    Text(
                      searchState.query.trim().isEmpty
                          ? 'Catalog Results (${searchState.results.length})'
                          : 'Matches for "${searchState.query}" (${searchState.results.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AnniTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (searchState.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),

            // 6. Results List with Quality Badges, Queue & Download Actions
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 165),
              sliver: searchState.results.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              LucideIcons.search,
                              size: 44,
                              color: AnniTheme.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No matching tracks found',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AnniTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try switching the provider filter to "All Sources" or searching another artist.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final Track track = searchState.results[index];
                          return AnniTrackTile(
                            track: track,
                            isPlaying: playback.currentTrack?.id == track.id &&
                                playback.isPlaying,
                            onTap: () {
                              ref
                                  .read(playbackStateProvider.notifier)
                                  .playTrack(track, queue: searchState.results);
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
                                    'Queued "${track.title}" for offline download.',
                                  ),
                                ),
                              );
                            },
                            trailing: IconButton(
                              tooltip: 'Play Next in Queue',
                              icon: const Icon(
                                LucideIcons.listPlus,
                                size: 18,
                                color: AnniTheme.textSecondary,
                              ),
                              onPressed: () {
                                ref
                                    .read(playbackStateProvider.notifier)
                                    .playNext(track);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${track.title}" will play next.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: searchState.results.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AnniTheme.primaryGradient : null,
          color: selected ? null : AnniTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : AnniTheme.glassBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AnniTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreTileData {
  const _GenreTileData({
    required this.name,
    required this.subtitle,
    required this.colorA,
    required this.colorB,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final Color colorA;
  final Color colorB;
  final IconData icon;
}

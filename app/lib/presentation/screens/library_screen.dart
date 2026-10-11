import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';
import '../widgets/tag_editor_sheet.dart';
import 'detail_screens.dart';

/// 7-Tab Audiophile Local & Cloud Library Screen:
/// `Songs`, `Albums`, `Artists`, `Genres`, `Folders`, `Playlists`, `Downloads`
/// Includes an interactive A–Z Fast Scroller rail for 10,000+ songs, Sort & Filter sheet,
/// Device MediaStore Scanner (`on_audio_query`), File/Folder Picker (`file_picker`),
/// and M3U Playlist Creator/Importer.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _songsScrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String? _activeAlphaLetter;

  static const List<String> _alphabet = <String>[
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _songsScrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _jumpToLetter(String letter, List<Track> tracks) {
    if (tracks.isEmpty || !_songsScrollController.hasClients) return;
    HapticFeedback.selectionClick();
    setState(() => _activeAlphaLetter = letter);

    int targetIdx = 0;
    if (letter != '#') {
      final int found = tracks.indexWhere(
        (Track t) => t.title.trim().toUpperCase().startsWith(letter),
      );
      if (found != -1) {
        targetIdx = found;
      }
    }

    final double offset = (targetIdx * 66.0).clamp(
      0.0,
      _songsScrollController.position.maxScrollExtent,
    );
    _songsScrollController.jumpTo(offset);
  }

  void _showSortSheet() {
    final LocalLibraryState libState = ref.read(localLibraryProvider);
    final LocalLibraryNotifier notifier = ref.read(localLibraryProvider.notifier);

    showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sort & Filter Local Library',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...LocalLibrarySortField.values.map((LocalLibrarySortField field) {
                final bool selected = libState.sortBy == field;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    color: selected
                        ? AnniTheme.accentMagenta
                        : AnniTheme.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    _formatSortField(field),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AnniTheme.textPrimary
                          : AnniTheme.textSecondary,
                    ),
                  ),
                  trailing: selected
                      ? Text(
                          libState.ascending ? 'ASC ↑' : 'DESC ↓',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AnniTheme.accentMagenta,
                          ),
                        )
                      : null,
                  onTap: () {
                    notifier.setSortField(field);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatSortField(LocalLibrarySortField field) {
    switch (field) {
      case LocalLibrarySortField.title:
        return 'Track Title (A–Z)';
      case LocalLibrarySortField.artist:
        return 'Artist Name';
      case LocalLibrarySortField.album:
        return 'Album Name';
      case LocalLibrarySortField.duration:
        return 'Track Duration';
      case LocalLibrarySortField.dateAdded:
        return 'Date Added / Release Year';
    }
  }

  Future<void> _showCreateOrImportPlaylistDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    bool isPublic = true;

    await showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 24 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Create or Import Playlist',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Playlist Name (e.g. Midnight FLAC Sessions)',
                      prefixIcon: Icon(LucideIcons.listMusic, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Description (optional)',
                      prefixIcon: Icon(LucideIcons.alignLeft, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Public Shareable Link'),
                    subtitle: const Text('Generate a public URL slug for sharing'),
                    activeColor: AnniTheme.accentMagenta,
                    value: isPublic,
                    onChanged: (bool val) =>
                        setModalState(() => isPublic = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final FilePickerResult? res =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.any,
                              );
                              if (res != null && res.files.single.path != null) {
                                final File f = File(res.files.single.path!);
                                final String content = await f.readAsString();
                                await ref
                                    .read(playlistsProvider.notifier)
                                    .importFromM3u(
                                      content,
                                      name: res.files.single.name
                                          .replaceAll('.m3u8', '')
                                          .replaceAll('.m3u', ''),
                                    );
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(LucideIcons.fileUp, size: 16),
                          label: const Text('Import .M3U File'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            await ref
                                .read(playlistsProvider.notifier)
                                .createPlaylist(
                                  name: nameCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  isPublic: isPublic,
                                  initialTracks:
                                      kSeededLegalCatalog.take(3).toList(),
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Create Playlist'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AnniTheme.accentViolet,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final LocalLibraryState libState = ref.watch(localLibraryProvider);
    final LocalLibraryNotifier libNotifier =
        ref.read(localLibraryProvider.notifier);
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final List<Playlist> playlists = ref.watch(playlistsProvider);
    final DownloadsState downloadsState = ref.watch(downloadsProvider);

    // Combine local tracks + seeded catalog if local is empty so all 7 tabs are rich
    final List<Track> allSongs = libState.tracks.isNotEmpty
        ? libState.tracks
        : kSeededLegalCatalog;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 1. Top Toolbar: Title + Scan Device + Import Files/Folder + Sort + New Playlist
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Your Library',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AnniTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${allSongs.length} songs indexed • Hardware & Cloud ready',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AnniTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Scan Device MediaStore (on_audio_query)',
                    onPressed: libState.isScanning
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            await libNotifier.scanDeviceStorage(
                              forceRescan: true,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Scanned device storage (${ref.read(localLibraryProvider).tracks.length} tracks indexed).',
                                ),
                              ),
                            );
                          },
                    icon: libState.isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.radar, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Pick Local Audio Files',
                    onPressed: libNotifier.importFiles,
                    icon: const Icon(LucideIcons.filePlus2, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Pick Local Audio Folder',
                    onPressed: libNotifier.importFolder,
                    icon: const Icon(LucideIcons.folderPlus, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Create or Import M3U Playlist',
                    onPressed: _showCreateOrImportPlaylistDialog,
                    icon: const Icon(LucideIcons.listPlus, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Sort Library',
                    onPressed: _showSortSheet,
                    icon: const Icon(LucideIcons.arrowUpDown, size: 20),
                  ),
                ],
              ),
            ),

            // 2. Instant Local Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _filterController,
                  onChanged: libNotifier.setSearchQuery,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Filter songs, albums, folders or playlists...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(LucideIcons.filter, size: 16),
                    suffixIcon: _filterController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 15),
                            onPressed: () {
                              _filterController.clear();
                              libNotifier.setSearchQuery('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // 3. 7-Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AnniTheme.accentMagenta,
              labelColor: AnniTheme.textPrimary,
              unselectedLabelColor: AnniTheme.textSecondary,
              dividerColor: AnniTheme.glassBorder,
              labelStyle: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              tabs: const <Tab>[
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
                Tab(text: 'Genres'),
                Tab(text: 'Folders'),
                Tab(text: 'Playlists'),
                Tab(text: 'Downloads'),
              ],
            ),

            // 4. 7 Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  // TAB 1: SONGS (with A-Z Fast Scroller on right edge)
                  _buildSongsTabWithAlphabetScroller(allSongs, playback),

                  // TAB 2: ALBUMS
                  _buildAlbumsTab(libState, allSongs),

                  // TAB 3: ARTISTS
                  _buildArtistsTab(libState, allSongs),

                  // TAB 4: GENRES
                  _buildGenresTab(allSongs, playback),

                  // TAB 5: FOLDERS
                  _buildFoldersTab(libState, allSongs, playback),

                  // TAB 6: PLAYLISTS
                  _buildPlaylistsTab(playlists),

                  // TAB 7: DOWNLOADS
                  _buildDownloadsTab(downloadsState, playback),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsTabWithAlphabetScroller(
    List<Track> songs,
    AnniPlaybackState playback,
  ) {
    return Stack(
      children: <Widget>[
        ListView.builder(
          controller: _songsScrollController,
          padding: const EdgeInsets.only(right: 24, bottom: 165, top: 6),
          itemCount: songs.length,
          itemExtent: 68.0,
          itemBuilder: (BuildContext context, int index) {
            final Track track = songs[index];
            return AnniTrackTile(
              track: track,
              isPlaying: playback.currentTrack?.id == track.id &&
                  playback.isPlaying,
              onTap: () {
                ref
                    .read(playbackStateProvider.notifier)
                    .playTrack(track, queue: songs);
              },
              onFavoriteToggle: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(track);
              },
              onMoreTap: () => TagEditorSheet.show(context, track),
            );
          },
        ),

        // Right-edge A–Z Fast Scroller Rail
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 24,
            margin: const EdgeInsets.only(bottom: 140, right: 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AnniTheme.surface2.withOpacity(0.76),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AnniTheme.glassBorder),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (DragUpdateDetails details) {
                    final double ratio =
                        (details.localPosition.dy / constraints.maxHeight)
                            .clamp(0.0, 0.999);
                    final int idx = (ratio * _alphabet.length).floor();
                    _jumpToLetter(_alphabet[idx], songs);
                  },
                  onVerticalDragEnd: (_) {
                    setState(() => _activeAlphaLetter = null);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _alphabet.map((String letter) {
                      final bool active = _activeAlphaLetter == letter;
                      return GestureDetector(
                        onTap: () => _jumpToLetter(letter, songs),
                        child: Text(
                          letter,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                            color: active
                                ? AnniTheme.accentMagenta
                                : AnniTheme.textTertiary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsTab(LocalLibraryState libState, List<Track> allSongs) {
    final Map<String, List<Track>> albumsMap = <String, List<Track>>{};
    for (final Track t in allSongs) {
      albumsMap.putIfAbsent(t.album, () => <Track>[]).add(t);
    }
    final List<String> albumNames = albumsMap.keys.toList();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 165),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: albumNames.length,
      itemBuilder: (BuildContext context, int index) {
        final String album = albumNames[index];
        final List<Track> tracks = albumsMap[album]!;
        final Track first = tracks.first;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlbumDetailScreen(
                  albumName: album,
                  tracks: tracks,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AnniTheme.surface1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AnniTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: AnniArtworkWidget(
                      artworkUrl: first.artworkUrl,
                      dominantHex: first.dominantColor,
                      size: 140,
                      borderRadius: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AnniTheme.textPrimary,
                  ),
                ),
                Text(
                  '${first.artist} • ${tracks.length} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AnniTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistsTab(LocalLibraryState libState, List<Track> allSongs) {
    final Map<String, List<Track>> artistsMap = <String, List<Track>>{};
    for (final Track t in allSongs) {
      artistsMap.putIfAbsent(t.artist, () => <Track>[]).add(t);
    }
    final List<String> artistNames = artistsMap.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 165),
      itemCount: artistNames.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final String artist = artistNames[index];
        final List<Track> tracks = artistsMap[artist]!;
        final Track sample = tracks.first;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: AnniArtworkWidget(
            artworkUrl: sample.artworkUrl,
            dominantHex: sample.dominantColor,
            size: 52,
            borderRadius: 26,
          ),
          title: Text(
            artist,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AnniTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '${tracks.length} tracks • ${sample.genre}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AnniTheme.textSecondary,
            ),
          ),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArtistDetailScreen(
                  artistName: artist,
                  tracks: tracks,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGenresTab(List<Track> allSongs, AnniPlaybackState playback) {
    final Map<String, List<Track>> genresMap = <String, List<Track>>{};
    for (final Track t in allSongs) {
      genresMap.putIfAbsent(t.genre, () => <Track>[]).add(t);
    }
    final List<String> genreNames = genresMap.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 165),
      itemCount: genreNames.length,
      itemBuilder: (BuildContext context, int index) {
        final String genre = genreNames[index];
        final List<Track> tracks = genresMap[genre]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(
              LucideIcons.music,
              color: AnniTheme.accentViolet,
            ),
            title: Text(
              genre,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text('${tracks.length} tracks'),
            children: tracks.map((Track t) {
              return AnniTrackTile(
                track: t,
                isPlaying:
                    playback.currentTrack?.id == t.id && playback.isPlaying,
                onTap: () {
                  ref
                      .read(playbackStateProvider.notifier)
                      .playTrack(t, queue: tracks);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFoldersTab(
    LocalLibraryState libState,
    List<Track> allSongs,
    AnniPlaybackState playback,
  ) {
    final Map<String, List<Track>> folders = libState.foldersMap.isNotEmpty
        ? libState.foldersMap
        : <String, List<Track>>{
            '/storage/emulated/0/Music/AnniLossless': allSongs,
          };
    final List<String> paths = folders.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 165),
      itemCount: paths.length,
      itemBuilder: (BuildContext context, int index) {
        final String folderPath = paths[index];
        final List<Track> tracks = folders[folderPath]!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            leading: const Icon(
              LucideIcons.folderOpen,
              color: AnniTheme.accentOrange,
            ),
            title: Text(
              folderPath.split(RegExp(r'[/\\]')).last,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '$folderPath • ${tracks.length} files',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AnniTheme.textTertiary,
              ),
            ),
            children: tracks.map((Track t) {
              return AnniTrackTile(
                track: t,
                isPlaying:
                    playback.currentTrack?.id == t.id && playback.isPlaying,
                onTap: () {
                  ref
                      .read(playbackStateProvider.notifier)
                      .playTrack(t, queue: tracks);
                },
                onMoreTap: () => TagEditorSheet.show(context, t),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(List<Playlist> playlists) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 165),
      itemCount: playlists.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: _showCreateOrImportPlaylistDialog,
              icon: const Icon(LucideIcons.plusCircle, size: 18),
              label: const Text('Create New Playlist or Import .M3U8'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AnniTheme.accentMagenta,
                side: const BorderSide(color: AnniTheme.accentMagenta),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );
        }

        final Playlist pl = playlists[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: AnniArtworkWidget(
              artworkUrl: pl.effectiveCoverUrl,
              size: 56,
              borderRadius: 12,
            ),
            title: Text(
              pl.name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${pl.trackCount} tracks • ${pl.formattedTotalDuration}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AnniTheme.textSecondary,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18),
              onPressed: () {
                ref.read(playlistsProvider.notifier).deletePlaylist(pl.id);
              },
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDownloadsTab(
    DownloadsState downloadsState,
    AnniPlaybackState playback,
  ) {
    final List<DownloadTaskItem> completed = downloadsState.completedTasks;
    if (completed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                LucideIcons.downloadCloud,
                size: 48,
                color: AnniTheme.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'No Offline Downloads Yet',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Download any Jamendo CC or Internet Archive track to listen offline in studio quality.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AnniTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Track> tracks =
        completed.map((DownloadTaskItem e) => e.track).toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 165, top: 8),
      itemCount: tracks.length,
      itemBuilder: (BuildContext context, int index) {
        final Track t = tracks[index];
        return AnniTrackTile(
          track: t,
          isPlaying: playback.currentTrack?.id == t.id && playback.isPlaying,
          onTap: () {
            ref
                .read(playbackStateProvider.notifier)
                .playTrack(t, queue: tracks);
          },
        );
      },
    );
  }
}

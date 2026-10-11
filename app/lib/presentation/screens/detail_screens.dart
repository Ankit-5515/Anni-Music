import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';
import '../widgets/tag_editor_sheet.dart';

// =============================================================================
// 1. ALBUM DETAIL SCREEN
// =============================================================================

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.tracks,
  });

  final String albumName;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final Track sample = tracks.isNotEmpty
        ? tracks.first
        : kSeededLegalCatalog.first;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            backgroundColor: AnniTheme.surface1,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AnniTheme.parseHexColor(sample.dominantColor)
                              .withOpacity(0.55),
                          AnniTheme.background,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: AnniArtworkWidget(
                        artworkUrl: sample.artworkUrl,
                        dominantHex: sample.dominantColor,
                        size: 164,
                        borderRadius: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Share Album',
                icon: const Icon(LucideIcons.share2, size: 20),
                onPressed: () {
                  Share.share(
                    'Listen to $albumName by ${sample.artist} on Anni Music — https://anni.music/album/${Uri.encodeComponent(albumName)}',
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      QualityBadge(label: sample.qualityBadge),
                      const SizedBox(width: 8),
                      Text(
                        '${sample.artist} • ${tracks.length} tracks • ${sample.releaseYear ?? 2025}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AnniTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AnniTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (tracks.isNotEmpty) {
                                ref
                                    .read(playbackStateProvider.notifier)
                                    .playTrack(tracks.first, queue: tracks);
                              }
                            },
                            icon: const Icon(
                              LucideIcons.play,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Play Album',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (tracks.isNotEmpty) {
                              await ref
                                  .read(playbackStateProvider.notifier)
                                  .playTrack(tracks.first, queue: tracks);
                              if (!ref.read(playbackStateProvider).shuffleEnabled) {
                                await ref
                                    .read(playbackStateProvider.notifier)
                                    .toggleShuffle();
                              }
                            }
                          },
                          icon: const Icon(LucideIcons.shuffle, size: 17),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnniTheme.textPrimary,
                            side: const BorderSide(color: AnniTheme.glassBorder),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final Track t = tracks[index];
                  return AnniTrackTile(
                    track: t,
                    indexNumber: index + 1,
                    isPlaying:
                        playback.currentTrack?.id == t.id && playback.isPlaying,
                    onTap: () {
                      ref
                          .read(playbackStateProvider.notifier)
                          .playTrack(t, queue: tracks);
                    },
                    onFavoriteToggle: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(t);
                    },
                    onMoreTap: () => TagEditorSheet.show(context, t),
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. ARTIST DETAIL SCREEN
// =============================================================================

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    required this.tracks,
  });

  final String artistName;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final Track sample = tracks.isNotEmpty
        ? tracks.first
        : kSeededLegalCatalog.first;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AnniTheme.surface1,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                artistName,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          AnniTheme.accentViolet.withOpacity(0.55),
                          AnniTheme.accentMagenta.withOpacity(0.35),
                          AnniTheme.background,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: AnniArtworkWidget(
                        artworkUrl: sample.artworkUrl,
                        dominantHex: sample.dominantColor,
                        size: 148,
                        borderRadius: 74,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Share Artist Profile',
                icon: const Icon(LucideIcons.share2, size: 20),
                onPressed: () {
                  Share.share(
                    'Explore $artistName on Anni Music — https://anni.music/artist/${Uri.encodeComponent(artistName)}',
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: <Widget>[
                  QualityBadge(label: 'VERIFIED ARTIST • ${sample.genre}'),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (tracks.isNotEmpty) {
                        ref
                            .read(playbackStateProvider.notifier)
                            .playTrack(tracks.first, queue: tracks);
                      }
                    },
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Play Discography'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AnniTheme.accentViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final Track t = tracks[index];
                  return AnniTrackTile(
                    track: t,
                    indexNumber: index + 1,
                    isPlaying:
                        playback.currentTrack?.id == t.id && playback.isPlaying,
                    onTap: () {
                      ref
                          .read(playbackStateProvider.notifier)
                          .playTrack(t, queue: tracks);
                    },
                    onFavoriteToggle: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(t);
                    },
                    onDownloadTap: () {
                      ref.read(downloadsProvider.notifier).enqueueDownload(t);
                    },
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. PLAYLIST DETAIL SCREEN (With Reorder, Cover Upload, M3U Export/Import & Share)
// =============================================================================

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  final Playlist playlist;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  Future<void> _uploadCustomCover() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        final Playlist updated = _playlist.copyWith(
          coverUrl: result.files.single.path,
          updatedAt: DateTime.now(),
        );
        await ref.read(musicRepositoryProvider).updatePlaylist(updated);
        await ref.read(playlistsProvider.notifier).loadPlaylists();
        if (mounted) {
          setState(() => _playlist = updated);
        }
      }
    } catch (_) {}
  }

  Future<void> _reorderTrack(int oldIndex, int newIndex) async {
    final List<Track> items = List<Track>.from(_playlist.tracks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Track moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    final Playlist updated = _playlist.copyWith(
      tracks: items,
      updatedAt: DateTime.now(),
    );
    setState(() => _playlist = updated);
    await ref.read(musicRepositoryProvider).updatePlaylist(updated);
    await ref.read(playlistsProvider.notifier).loadPlaylists();
  }

  Future<void> _showM3uModal() async {
    final String m3uText = _playlist.toM3u();
    final TextEditingController controller = TextEditingController(text: m3uText);

    await showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    LucideIcons.fileCode,
                    color: AnniTheme.accentViolet,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'M3U8 Playlist Export / Import',
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.copy, size: 18),
                    tooltip: 'Copy M3U Content',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Extended .m3u8 content copied to clipboard!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  color: AnniTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final String savedPath = await ref
                            .read(playlistsProvider.notifier)
                            .exportToM3u(_playlist);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Exported M3U8 file to: $savedPath'),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.download, size: 16),
                      label: const Text('Save .m3u8 File'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final Playlist imported = await ref
                            .read(playlistsProvider.notifier)
                            .importFromM3u(
                              controller.text,
                              name: '${_playlist.name} (Imported)',
                            );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        setState(() => _playlist = imported);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported "${imported.name}" (${imported.trackCount} tracks)!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.upload, size: 16),
                      label: const Text('Import M3U'),
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
  }

  void _sharePlaylistLink() {
    final String slug = _playlist.shareSlug ??
        _playlist.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final String url = 'https://anni.music/playlist/$slug';
    Clipboard.setData(ClipboardData(text: url));
    Share.share('Check out my "${_playlist.name}" playlist on Anni Music: $url');
  }

  @override
  Widget build(BuildContext context) {
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AnniTheme.surface1,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AnniTheme.accentMagenta.withOpacity(0.45),
                          AnniTheme.background,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: GestureDetector(
                        onTap: _uploadCustomCover,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: <Widget>[
                            AnniArtworkWidget(
                              artworkUrl: _playlist.effectiveCoverUrl,
                              size: 164,
                              borderRadius: 22,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AnniTheme.accentViolet,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'M3U8 Import / Export',
                icon: const Icon(LucideIcons.fileCode, size: 20),
                onPressed: _showM3uModal,
              ),
              IconButton(
                tooltip: 'Share Public Link',
                icon: const Icon(LucideIcons.share2, size: 20),
                onPressed: _sharePlaylistLink,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_playlist.description.isNotEmpty) ...<Widget>[
                    Text(
                      _playlist.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: AnniTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: <Widget>[
                      QualityBadge(
                        label: _playlist.isPublic ? 'PUBLIC LINK' : 'PRIVATE',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_playlist.trackCount} tracks • ${_playlist.formattedTotalDuration} • Drag to reorder',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AnniTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AnniTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_playlist.tracks.isNotEmpty) {
                                ref
                                    .read(playbackStateProvider.notifier)
                                    .playTrack(
                                      _playlist.tracks.first,
                                      queue: _playlist.tracks,
                                    );
                              }
                            },
                            icon: const Icon(
                              LucideIcons.play,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Play All',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showM3uModal,
                          icon: const Icon(LucideIcons.fileSpreadsheet, size: 17),
                          label: const Text('Export M3U8'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnniTheme.textPrimary,
                            side: const BorderSide(color: AnniTheme.glassBorder),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120),
            sliver: SliverReorderableList(
              itemCount: _playlist.tracks.length,
              onReorder: _reorderTrack,
              itemBuilder: (BuildContext context, int index) {
                final Track track = _playlist.tracks[index];
                return Material(
                  key: ValueKey<String>('${track.id}_$index'),
                  color: Colors.transparent,
                  child: AnniTrackTile(
                    track: track,
                    indexNumber: index + 1,
                    isPlaying: playback.currentTrack?.id == track.id &&
                        playback.isPlaying,
                    onTap: () {
                      ref
                          .read(playbackStateProvider.notifier)
                          .playTrack(track, queue: _playlist.tracks);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove from Playlist',
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: AnniTheme.textTertiary,
                          ),
                          onPressed: () async {
                            await ref
                                .read(playlistsProvider.notifier)
                                .removeTrackFromPlaylist(
                                  _playlist.id,
                                  track.id,
                                );
                            setState(() {
                              _playlist = _playlist.copyWith(
                                tracks: _playlist.tracks
                                    .where((Track t) => t.id != track.id)
                                    .toList(),
                              );
                            });
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(
                              LucideIcons.gripVertical,
                              size: 18,
                              color: AnniTheme.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';
import '../widgets/tag_editor_sheet.dart';
import 'equalizer_screen.dart';

/// Showpiece Full-Screen Now Playing Experience for Anni Music.
/// Features:
/// - Dynamic Palette Animated Blurred Mesh Gradient Background
/// - 24px Rounded Artwork with Soft Colored Glow OR Official YouTube IFrame Player (`TrackSource.youtube`)
/// - Interactive 48-Bar Animated Waveform Visualizer + Precision Seek Bar with Haptics
/// - Toggleable Synchronized LRC Lyrics Karaoke View with Auto-Scroll & Tap-to-Seek
/// - Shuffle, Previous, Gradient Play/Pause Morph, Next, Repeat (Off/All/One)
/// - Bottom Action Dock: Speed (0.5x–2.0x), Sleep Timer, 10-Band EQ, Add to Playlist, Tag Editor/Ringtone, Share, & Draggable Queue Sheet
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _meshController;
  final ScrollController _lyricsScrollController = ScrollController();
  YoutubePlayerController? _ytController;
  String? _loadedYtVideoId;
  bool _showLyrics = false;
  int _lastScrolledLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _meshController.dispose();
    _lyricsScrollController.dispose();
    _ytController?.close();
    super.dispose();
  }

  void _ensureYouTubeController(Track track) {
    if (!track.isYouTube) return;
    final String videoId =
        track.externalId.isNotEmpty ? track.externalId : 'jfKfPfyJRdk';
    if (_loadedYtVideoId == videoId && _ytController != null) return;

    try {
      _ytController?.close();
      _loadedYtVideoId = videoId;
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
    } catch (_) {
      // Safe fallback in headless test environments without WebView platform implementation
      _ytController = null;
    }
  }

  String _formatDuration(Duration d) {
    final int totalSec = math.max(0, d.inSeconds);
    final int mins = totalSec ~/ 60;
    final int secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _autoScrollLyrics(int activeIdx) {
    if (!_showLyrics ||
        activeIdx == _lastScrolledLyricIndex ||
        activeIdx < 0 ||
        !_lyricsScrollController.hasClients) {
      return;
    }
    _lastScrolledLyricIndex = activeIdx;
    final double targetOffset = math.max(0.0, (activeIdx * 54.0) - 110.0);
    _lyricsScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _lyricsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSpeedSheet(AnniPlaybackState playback) {
    const List<double> speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
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
                'Playback Speed & Pitch Control',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: speeds.map((double s) {
                  final bool selected =
                      (playback.playbackSpeed - s).abs() < 0.05;
                  return ChoiceChip(
                    label: Text('${s}x'),
                    selected: selected,
                    selectedColor: AnniTheme.accentMagenta,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(playbackStateProvider.notifier)
                          .setPlaybackSpeed(s);
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerSheet(AnniPlaybackState playback) {
    final PlaybackStateNotifier notifier =
        ref.read(playbackStateProvider.notifier);

    showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    LucideIcons.moon,
                    color: AnniTheme.accentViolet,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sleep Timer',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (playback.sleepTimerRemaining != null)
                    TextButton(
                      onPressed: () {
                        notifier.cancelSleepTimer();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Cancel Timer',
                        style: TextStyle(color: AnniTheme.error),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...[15, 30, 45, 60].map((int mins) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.clock, size: 18),
                  title: Text('Stop audio in $mins minutes'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    notifier.startSleepTimer(Duration(minutes: mins));
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.music, size: 18),
                title: const Text('Stop at End of Current Track'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  notifier.startSleepTimer(
                    const Duration(minutes: 3),
                    endOfTrack: true,
                  );
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(Track track) {
    final List<Playlist> playlists = ref.read(playlistsProvider);
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
                'Add "${track.title}" to Playlist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...playlists.map((Playlist pl) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AnniArtworkWidget(
                    artworkUrl: pl.effectiveCoverUrl,
                    size: 44,
                    borderRadius: 10,
                  ),
                  title: Text(pl.name),
                  subtitle: Text('${pl.trackCount} tracks'),
                  trailing: const Icon(LucideIcons.plusCircle, size: 18),
                  onTap: () async {
                    await ref
                        .read(playlistsProvider.notifier)
                        .addTrackToPlaylist(pl.id, track);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${track.title}" to ${pl.name}'),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showQueueSheet() {
    showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final AnniPlaybackState state = ref.watch(playbackStateProvider);
            final PlaybackStateNotifier notifier =
                ref.read(playbackStateProvider.notifier);

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          LucideIcons.listMusic,
                          color: AnniTheme.accentMagenta,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Up Next Queue (${state.queue.length})',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Drag handle to reorder • Swipe left to remove',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            notifier.clearQueue();
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: state.queue.length,
                      onReorder: notifier.reorderQueue,
                      itemBuilder: (BuildContext context, int index) {
                        final Track item = state.queue[index];
                        final bool isCurrent = index == state.currentIndex;
                        return Dismissible(
                          key: ValueKey<String>('q_${item.id}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: AnniTheme.error.withOpacity(0.24),
                            child: const Icon(
                              LucideIcons.trash2,
                              color: AnniTheme.error,
                            ),
                          ),
                          onDismissed: (_) => notifier.removeFromQueue(index),
                          child: ListTile(
                            leading: AnniArtworkWidget(
                              artworkUrl: item.artworkUrl,
                              dominantHex: item.dominantColor,
                              size: 44,
                              borderRadius: 10,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? AnniTheme.accentMagenta
                                    : AnniTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${item.artist} • ${item.formattedDuration}',
                              maxLines: 1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                LucideIcons.gripVertical,
                                size: 18,
                                color: AnniTheme.textTertiary,
                              ),
                            ),
                            onTap: () => notifier.skipToQueueItem(index),
                          ),
                        );
                      },
                    ),
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
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final PlaybackStateNotifier notifier =
        ref.read(playbackStateProvider.notifier);
    final Track track = playback.currentTrack ?? kSeededLegalCatalog.first;

    _ensureYouTubeController(track);

    final AsyncValue<Color> paletteAsync = ref.watch(dynamicPaletteProvider);
    final Color dominantColor = paletteAsync.valueOrNull ??
        AnniTheme.parseHexColor(track.dominantColor);

    final bool isFav = ref
        .watch(favoritesProvider)
        .any((Track f) => f.id == track.id);

    final AsyncValue<List<LrcLine>> lyricsAsync = ref.watch(lyricsProvider);

    return Scaffold(
      backgroundColor: AnniTheme.background,
      body: Stack(
        children: <Widget>[
          // 1. Animated Blurred Mesh Gradient Background extracted from Album Art
          AnimatedBuilder(
            animation: _meshController,
            builder: (BuildContext context, Widget? child) {
              final double t = _meshController.value;
              return Stack(
                children: <Widget>[
                  Positioned(
                    top: -80 + (t * 45),
                    left: -50 + (t * 35),
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            dominantColor.withOpacity(0.46),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80 - (t * 40),
                    right: -60 + (t * 30),
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AnniTheme.accentMagenta.withOpacity(0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
                    child: Container(color: Colors.black.withOpacity(0.32)),
                  ),
                ],
              );
            },
          ),

          // 2. Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Column(
                children: <Widget>[
                  // Top Bar: Collapse Chevron, Source Pill, Lyrics Toggle & Queue Button
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Minimize Player',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(LucideIcons.chevronDown, size: 26),
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              'PLAYING FROM ${track.source.displayName.toUpperCase()}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AnniTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Toggle Synced Lyrics (LRC)',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showLyrics = !_showLyrics);
                        },
                        icon: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient:
                                _showLyrics ? AnniTheme.primaryGradient : null,
                            color: _showLyrics ? null : AnniTheme.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AnniTheme.glassBorder),
                          ),
                          child: Text(
                            'LRC',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Centerpiece Area: Artwork / YouTube IFrame Player / Synced LRC Lyrics
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showLyrics
                          ? _buildSyncedLyricsView(
                              lyricsAsync,
                              playback.position,
                              notifier,
                            )
                          : _buildArtworkOrYouTubeCenterpiece(
                              track,
                              dominantColor,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Title, Artist, Quality/License Badges & Favorite Burst
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AnniTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                QualityBadge(label: track.qualityBadge),
                                const SizedBox(width: 8),
                                QualityBadge(
                                  label: track.license,
                                  compact: true,
                                ),
                                if (playback.sleepTimerRemaining != null) ...<Widget>[
                                  const SizedBox(width: 8),
                                  QualityBadge(
                                    label:
                                        'SLEEP ${_formatDuration(playback.sleepTimerRemaining!)}',
                                    compact: true,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      FavoriteBurstButton(
                        isFavorite: isFav || track.isFavorite,
                        size: 28,
                        onToggle: () {
                          ref
                              .read(favoritesProvider.notifier)
                              .toggleFavorite(track);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. Interactive 48-Bar Animated Waveform + Seek Bar
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (DragUpdateDetails d) {
                      final RenderBox? box =
                          context.findRenderObject() as RenderBox?;
                      if (box != null && box.hasSize) {
                        final double ratio =
                            (d.localPosition.dx / (box.size.width - 44))
                                .clamp(0.0, 1.0);
                        HapticFeedback.selectionClick();
                        notifier.seekToRatio(ratio);
                      }
                    },
                    onTapDown: (TapDownDetails d) {
                      final RenderBox? box =
                          context.findRenderObject() as RenderBox?;
                      if (box != null && box.hasSize) {
                        final double ratio =
                            (d.localPosition.dx / (box.size.width - 44))
                                .clamp(0.0, 1.0);
                        HapticFeedback.selectionClick();
                        notifier.seekToRatio(ratio);
                      }
                    },
                    child: SizedBox(
                      height: 42,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformSeekPainter(
                          waveform: track.effectiveWaveform,
                          progress: playback.progress,
                          isPlaying: playback.isPlaying,
                          accentColor: dominantColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _formatDuration(playback.position),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          color: AnniTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _formatDuration(
                          playback.duration.inSeconds > 0
                              ? playback.duration
                              : track.duration,
                        ),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          color: AnniTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Main Transport Controls: Shuffle, Previous, Gradient Play/Pause, Next, Repeat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Shuffle Queue',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          notifier.toggleShuffle();
                        },
                        icon: Icon(
                          LucideIcons.shuffle,
                          size: 21,
                          color: playback.shuffleEnabled
                              ? AnniTheme.accentMagenta
                              : AnniTheme.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous Track',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          notifier.skipToPrevious();
                        },
                        icon: const Icon(
                          LucideIcons.skipBack,
                          size: 28,
                          color: AnniTheme.textPrimary,
                        ),
                      ),
                      GradientPlayButton(
                        isPlaying: playback.isPlaying,
                        isBuffering: playback.isBuffering,
                        size: 70,
                        onPressed: notifier.togglePlayPause,
                      ),
                      IconButton(
                        tooltip: 'Next Track',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          notifier.skipToNext();
                        },
                        icon: const Icon(
                          LucideIcons.skipForward,
                          size: 28,
                          color: AnniTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Repeat Mode (${playback.repeatMode.name})',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          notifier.cycleRepeatMode();
                        },
                        icon: Icon(
                          playback.repeatMode == AnniRepeatMode.one
                              ? LucideIcons.repeat1
                              : LucideIcons.repeat,
                          size: 21,
                          color: playback.repeatMode != AnniRepeatMode.off
                              ? AnniTheme.accentMagenta
                              : AnniTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 7. Bottom Studio Action Dock (Speed, Sleep Timer, 10-Band EQ, Playlist, Tag/Ringtone, Share, Queue)
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    borderRadius: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _DockIconButton(
                          icon: LucideIcons.gauge,
                          label: '${playback.playbackSpeed}x',
                          onTap: () => _showSpeedSheet(playback),
                        ),
                        _DockIconButton(
                          icon: LucideIcons.moon,
                          label: 'Sleep',
                          isActive: playback.sleepTimerRemaining != null,
                          onTap: () => _showSleepTimerSheet(playback),
                        ),
                        _DockIconButton(
                          icon: LucideIcons.sliders,
                          label: '10-EQ',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const EqualizerScreen(),
                              ),
                            );
                          },
                        ),
                        _DockIconButton(
                          icon: LucideIcons.folderPlus,
                          label: 'Playlist',
                          onTap: () => _showAddToPlaylistSheet(track),
                        ),
                        _DockIconButton(
                          icon: LucideIcons.tags,
                          label: 'ID3/Ring',
                          onTap: () => TagEditorSheet.show(context, track),
                        ),
                        _DockIconButton(
                          icon: LucideIcons.share2,
                          label: 'Share',
                          onTap: () {
                            Share.share(
                              'Listening to "${track.title}" by ${track.artist} on Anni Music — https://anni.music/track/${track.id}',
                            );
                          },
                        ),
                        _DockIconButton(
                          icon: LucideIcons.listMusic,
                          label: 'Queue',
                          onTap: _showQueueSheet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkOrYouTubeCenterpiece(Track track, Color dominantColor) {
    if (track.isYouTube) {
      return Center(
        key: const ValueKey<String>('yt_iframe_player'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AnniTheme.accentMagenta.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AnniTheme.accentMagenta.withOpacity(0.26),
                blurRadius: 32,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: (_ytController != null && !kIsWeb)
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(
                    controller: _ytController!,
                    aspectRatio: 16 / 9,
                  ),
                )
              : Container(
                  height: 220,
                  width: double.infinity,
                  color: AnniTheme.surface2,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        LucideIcons.youtube,
                        size: 48,
                        color: AnniTheme.accentMagenta,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Official YouTube IFrame Player (${track.externalId})',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Streaming via compliant YouTube Embed API without audio ripping.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AnniTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    return Center(
      key: ValueKey<String>('art_${track.id}'),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double side =
              math.min(constraints.maxWidth, constraints.maxHeight) * 0.92;
          return Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: dominantColor.withOpacity(0.42),
                  blurRadius: 42,
                  spreadRadius: 4,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: AnniArtworkWidget(
              artworkUrl: track.artworkUrl,
              dominantHex: track.dominantColor,
              size: side,
              borderRadius: 24,
              heroTag: 'mini_art_${track.id}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildSyncedLyricsView(
    AsyncValue<List<LrcLine>> lyricsAsync,
    Duration currentPosition,
    PlaybackStateNotifier notifier,
  ) {
    return GlassCard(
      key: const ValueKey<String>('lrc_lyrics_view'),
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: lyricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Lyrics unavailable')),
        data: (List<LrcLine> lines) {
          final int activeIndex =
              LrcParser.findActiveLineIndex(lines, currentPosition);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoScrollLyrics(activeIndex);
          });

          return ListView.builder(
            controller: _lyricsScrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: lines.length,
            itemBuilder: (BuildContext context, int index) {
              final LrcLine line = lines[index];
              final bool isActive = index == activeIndex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.seek(line.timestamp);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: isActive ? 21 : 16,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : AnniTheme.textSecondary.withOpacity(0.55),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? AnniTheme.accentMagenta
                  : AnniTheme.textPrimary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AnniTheme.accentMagenta
                    : AnniTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformSeekPainter extends CustomPainter {
  const _WaveformSeekPainter({
    required this.waveform,
    required this.progress,
    required this.isPlaying,
    required this.accentColor,
  });

  final List<double> waveform;
  final double progress;
  final bool isPlaying;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    final int count = waveform.length;
    final double spacing = size.width / count;
    final double barWidth = math.max(2.5, spacing * 0.56);
    final double centerY = size.height / 2;

    for (int i = 0; i < count; i++) {
      final double barRatio = i / count;
      final bool isPlayed = barRatio <= progress;
      final double amp = waveform[i].clamp(0.15, 1.0);
      final double barHeight = math.max(6.0, size.height * amp);

      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((i * spacing) + (spacing / 2), centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(3),
      );

      final Paint paint = Paint()
        ..color = isPlayed
            ? AnniTheme.accentMagenta
            : Colors.white.withOpacity(0.20);
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformSeekPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.waveform != waveform;
}

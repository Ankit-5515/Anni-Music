import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import 'glass_components.dart';

/// Floating glassmorphic Mini-Player bar docked above the bottom navigation bar.
/// Supports:
/// - Tap or Swipe UP to expand the full Now Playing screen
/// - Swipe DOWN to dismiss/stop playback
/// - Swipe LEFT/RIGHT to skip to next/previous track with haptic feedback
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({
    super.key,
    required this.onExpandNowPlaying,
  });

  final VoidCallback onExpandNowPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final Track? track = playback.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final AsyncValue<Color> paletteAsync = ref.watch(dynamicPaletteProvider);
    final Color accentColor = paletteAsync.valueOrNull ??
        AnniTheme.parseHexColor(track.dominantColor);
    final bool isFav = ref
        .watch(favoritesProvider)
        .any((Track f) => f.id == track.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onExpandNowPlaying();
      },
      onVerticalDragEnd: (DragEndDetails details) {
        final double velocity = details.primaryVelocity ?? 0.0;
        if (velocity < -220) {
          // Swipe UP -> expand Now Playing
          HapticFeedback.lightImpact();
          onExpandNowPlaying();
        } else if (velocity > 260) {
          // Swipe DOWN -> dismiss/stop with Undo
          HapticFeedback.mediumImpact();
          final Track stoppedTrack = track;
          final List<Track> queue = List<Track>.from(playback.queue);
          ref.read(playbackStateProvider.notifier).stop();
          ref.read(playbackStateProvider.notifier).clearQueue();

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AnniTheme.surface2,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                'Playback stopped • ${stoppedTrack.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
              ),
              action: SnackBarAction(
                label: 'Undo',
                textColor: AnniTheme.accentViolet,
                onPressed: () {
                  ref.read(playbackStateProvider.notifier).playTrack(
                    stoppedTrack,
                    queue: queue.isNotEmpty ? queue : <Track>[stoppedTrack],
                  );
                },
              ),
            ),
          );
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        final double velocity = details.primaryVelocity ?? 0.0;
        if (velocity < -220) {
          // Swipe LEFT -> next track
          HapticFeedback.lightImpact();
          ref.read(playbackStateProvider.notifier).skipToNext();
        } else if (velocity > 220) {
          // Swipe RIGHT -> previous track
          HapticFeedback.lightImpact();
          ref.read(playbackStateProvider.notifier).skipToPrevious();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accentColor.withOpacity(0.18),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    accentColor.withOpacity(0.24),
                    AnniTheme.surface1.withOpacity(0.88),
                    AnniTheme.surface2.withOpacity(0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.09),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: <Widget>[
                        AnniArtworkWidget(
                          artworkUrl: track.artworkUrl,
                          dominantHex: track.dominantColor,
                          size: 46,
                          borderRadius: 12,
                          heroTag: 'mini_art_${track.id}',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  QualityBadge(
                                    label: track.qualityBadge,
                                    compact: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AnniTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${track.artist} • ${track.source.displayName}',
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
                        FavoriteBurstButton(
                          isFavorite: isFav || track.isFavorite,
                          size: 20,
                          onToggle: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(track);
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: playback.isPlaying ? 'Pause' : 'Play',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(playbackStateProvider.notifier).togglePlayPause();
                          },
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AnniTheme.primaryGradient,
                            ),
                            child: Icon(
                              playback.isPlaying ? LucideIcons.pause : LucideIcons.play,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Next Track',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(playbackStateProvider.notifier).skipToNext();
                          },
                          icon: const Icon(
                            LucideIcons.skipForward,
                            size: 19,
                            color: AnniTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated progress bar along bottom edge
                  SizedBox(
                    height: 2.6,
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double progressWidth =
                            constraints.maxWidth * playback.progress.clamp(0.0, 1.0);
                        return Stack(
                          children: <Widget>[
                            Container(
                              width: constraints.maxWidth,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: progressWidth,
                              decoration: const BoxDecoration(
                                gradient: AnniTheme.primaryGradient,
                              ),
                            ),
                          ],
                        );
                      },
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import 'glass_components.dart';

class TrackActionMenu extends ConsumerWidget {
  const TrackActionMenu({
    super.key,
    required this.track,
    this.playlistId,
  });

  final Track track;
  final String? playlistId;

  static Future<void> show(
    BuildContext context, {
    required Track track,
    String? playlistId,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => TrackActionMenu(track: track, playlistId: playlistId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFav = ref.watch(favoritesProvider).any((Track t) => t.id == track.id);
    final List<Playlist> playlists = ref.watch(playlistsProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AnniTheme.surface1.withOpacity(0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Pill handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: <Widget>[
                  AnniArtworkWidget(
                    artworkUrl: track.artworkUrl,
                    dominantHex: track.dominantColor,
                    size: 56,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AnniTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            QualityBadge(label: track.qualityBadge, compact: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${track.artist} • ${track.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 12),

              // Action Tiles
              _buildActionTile(
                icon: LucideIcons.play,
                label: 'Play Next',
                onTap: () {
                  ref.read(playbackStateProvider.notifier).playNext(track);
                  Navigator.pop(context);
                  _showSnack(context, 'Playing next: ${track.title}');
                },
              ),
              _buildActionTile(
                icon: LucideIcons.listPlus,
                label: 'Add to Queue',
                onTap: () {
                  ref.read(playbackStateProvider.notifier).addToQueue(track);
                  Navigator.pop(context);
                  _showSnack(context, 'Added to queue: ${track.title}');
                },
              ),
              _buildActionTile(
                icon: LucideIcons.folderPlus,
                label: 'Add to Playlist',
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, ref, playlists, track);
                },
              ),
              _buildActionTile(
                icon: isFav ? LucideIcons.heartOff : LucideIcons.heart,
                label: isFav ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                iconColor: isFav ? AnniTheme.accentMagenta : null,
                onTap: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(track);
                  Navigator.pop(context);
                  _showSnack(context, isFav ? 'Removed from Liked Songs' : 'Saved to Liked Songs');
                },
              ),
              if (track.canDownload)
                _buildActionTile(
                  icon: LucideIcons.download,
                  label: 'Download (Lossless FLAC)',
                  onTap: () {
                    ref.read(downloadManagerProvider).enqueueDownload(track);
                    Navigator.pop(context);
                    _showSnack(context, 'Downloading ${track.title}...');
                  },
                ),
              _buildActionTile(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: 'Listening to "${track.title}" by ${track.artist} on Anni Music: https://anni.music/track/${track.id}',
                  ));
                  Navigator.pop(context);
                  _showSnack(context, 'Share link copied to clipboard');
                },
              ),

              // Delete Option with Confirmation & Undo
              _buildActionTile(
                icon: LucideIcons.trash2,
                label: playlistId != null ? 'Remove from Playlist' : 'Delete from Library',
                iconColor: Colors.redAccent,
                labelColor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: iconColor ?? AnniTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AnniTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AnniTheme.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text(
          playlistId != null ? 'Remove track?' : 'Delete track?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AnniTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${track.title}"? You can undo this action.',
          style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((bool? confirmed) {
      if (confirmed == true) {
        if (playlistId != null) {
          ref.read(playlistsProvider.notifier).removeTrackFromPlaylist(playlistId!, track.id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AnniTheme.surface2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text(
              'Deleted "${track.title}"',
              style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AnniTheme.accentViolet,
              onPressed: () {
                if (playlistId != null) {
                  ref.read(playlistsProvider.notifier).addTrackToPlaylist(playlistId!, track);
                }
              },
            ),
          ),
        );
      }
    });
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists,
    Track track,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: AnniTheme.surface1.withOpacity(0.95),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Add to Playlist',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AnniTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No playlists created yet.',
                        style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ...playlists.map((Playlist p) => ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AnniTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.music, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          p.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: AnniTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${p.tracks.length} tracks',
                          style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary, fontSize: 12),
                        ),
                        onTap: () {
                          ref.read(playlistsProvider.notifier).addTrackToPlaylist(p.id, track);
                          Navigator.pop(ctx);
                          _showSnack(context, 'Added to ${p.name}');
                        },
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AnniTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const QueueScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnniPlaybackState playback = ref.watch(playbackStateProvider);
    final PlaybackStateNotifier notifier = ref.read(playbackStateProvider.notifier);
    final Track? currentTrack = playback.currentTrack;
    final List<Track> queue = playback.queue;
    final int currentIndex = playback.currentIndex;

    return Scaffold(
      backgroundColor: AnniTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronDown, color: AnniTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Queue',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AnniTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          if (queue.isNotEmpty)
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                notifier.clearQueue();
              },
              child: Text(
                'Clear',
                style: GoogleFonts.plusJakartaSans(
                  color: AnniTheme.accentViolet,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: queue.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      LucideIcons.listMusic,
                      size: 56,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Queue is empty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AnniTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Play a track to start building your queue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AnniTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: <Widget>[
                  // Now Playing Section
                  if (currentTrack != null) ...<Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                        child: Text(
                          'Now Playing',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AnniTheme.accentMagenta,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AnniTheme.surface1.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AnniTheme.accentMagenta.withOpacity(0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            AnniArtworkWidget(
                              artworkUrl: currentTrack.artworkUrl,
                              dominantHex: currentTrack.dominantColor,
                              size: 48,
                              borderRadius: 12,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    currentTrack.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AnniTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentTrack.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AnniTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AnniTheme.accentMagenta.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    LucideIcons.barChart2,
                                    size: 14,
                                    color: AnniTheme.accentMagenta,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Playing',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AnniTheme.accentMagenta,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Up Next Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                      child: Row(
                        children: <Widget>[
                          Text(
                            'Up Next',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AnniTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Hold & drag to reorder',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AnniTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reorderable Queue List
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: queue.length,
                      onReorder: (int oldIndex, int newIndex) {
                        HapticFeedback.mediumImpact();
                        notifier.reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (BuildContext ctx, int index) {
                        final Track track = queue[index];
                        final bool isCurrent = index == currentIndex;

                        return Dismissible(
                          key: ValueKey<String>('queue_item_${track.id}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.24),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                          ),
                          onDismissed: (_) {
                            HapticFeedback.lightImpact();
                            notifier.removeFromQueue(index);
                          },
                          child: Container(
                            key: ValueKey<String>('tile_${track.id}_$index'),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AnniTheme.accentViolet.withOpacity(0.12)
                                  : AnniTheme.surface1.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrent
                                    ? AnniTheme.accentViolet.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: AnniArtworkWidget(
                                artworkUrl: track.artworkUrl,
                                dominantHex: track.dominantColor,
                                size: 42,
                                borderRadius: 10,
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isCurrent ? AnniTheme.accentViolet : AnniTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${track.artist} • ${track.formattedDuration}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    LucideIcons.gripVertical,
                                    size: 20,
                                    color: AnniTheme.textTertiary,
                                  ),
                                ),
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                notifier.skipToQueueItem(index);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

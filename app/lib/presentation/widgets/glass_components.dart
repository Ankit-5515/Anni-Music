import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../domain/entities/track.dart';

/// Frosted glassmorphic container using [BackdropFilter] with sigma 28 blur
/// and subtle `Colors.white.withOpacity(0.09)` border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20.0,
    this.blurSigma = 28.0,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveBg = backgroundColor ??
        (isDark
            ? AnniTheme.surface1.withOpacity(0.74)
            : Colors.white.withOpacity(0.82));
    final Color effectiveBorder = borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.09)
            : Colors.black.withOpacity(0.08));

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: 1.0),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}

/// High-contrast technical quality badge (`FLAC`, `FLAC 24-bit`, `320kbps`, `YT-HD`, `LOCAL`).
class QualityBadge extends StatelessWidget {
  const QualityBadge({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String upper = label.toUpperCase();
    final bool isHiRes = upper.contains('FLAC') || upper.contains('LOSSLESS') || upper.contains('24-BIT');
    final bool isYouTube = upper.contains('YT');

    final Color tint = isHiRes
        ? AnniTheme.accentOrange
        : isYouTube
            ? AnniTheme.accentMagenta
            : AnniTheme.accentViolet;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withOpacity(0.45), width: 0.9),
      ),
      child: Text(
        upper,
        style: GoogleFonts.jetBrainsMono(
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w700,
          color: tint,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Badge indicating a track is stored offline and ready for zero-data playback.
class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AnniTheme.success.withOpacity(0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.arrowDownCircle,
          size: 13,
          color: AnniTheme.success,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AnniTheme.success.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AnniTheme.success.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            LucideIcons.checkCircle2,
            size: 11,
            color: AnniTheme.success,
          ),
          const SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AnniTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering skeleton box for loading states.
class AnniShimmerBox extends StatefulWidget {
  const AnniShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AnniShimmerBox> createState() => _AnniShimmerBoxState();
}

class _AnniShimmerBoxState extends State<AnniShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double slide = (_controller.value * 2) - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(slide - 1.0, -0.2),
              end: Alignment(slide + 1.0, 0.2),
              colors: const <Color>[
                AnniTheme.surface1,
                AnniTheme.surface3,
                AnniTheme.surface1,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated Play/Pause morph button with Anni Music signature gradient and glow.
class GradientPlayButton extends StatelessWidget {
  const GradientPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 64.0,
    this.isBuffering = false,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AnniTheme.primaryGradient,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AnniTheme.accentMagenta.withOpacity(isPlaying ? 0.45 : 0.28),
              blurRadius: size * 0.42,
              spreadRadius: isPlaying ? 2 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isBuffering
              ? SizedBox(
                  width: size * 0.42,
                  height: size * 0.42,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    return ScaleTransition(scale: anim, child: child);
                  },
                  child: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    key: ValueKey<bool>(isPlaying),
                    color: Colors.white,
                    size: size * 0.44,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Animated heart button with particle ring burst when toggled to favorite.
class FavoriteBurstButton extends StatefulWidget {
  const FavoriteBurstButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 22.0,
  });

  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;

  @override
  State<FavoriteBurstButton> createState() => _FavoriteBurstButtonState();
}

class _FavoriteBurstButtonState extends State<FavoriteBurstButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant FavoriteBurstButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _burstController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onToggle();
      },
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: AnimatedBuilder(
          animation: _burstController,
          builder: (BuildContext context, Widget? child) {
            final double v = _burstController.value;
            final double scale = v < 0.5
                ? 1.0 + (v * 0.7)
                : 1.35 - ((v - 0.5) * 0.7);
            return CustomPaint(
              painter: _HeartBurstPainter(progress: v),
              child: Transform.scale(
                scale: _burstController.isAnimating ? scale : 1.0,
                child: Icon(
                  widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: widget.size,
                  color: widget.isFavorite
                      ? AnniTheme.accentMagenta
                      : AnniTheme.textSecondary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeartBurstPainter extends CustomPainter {
  const _HeartBurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width * 0.95;
    final double radius = maxRadius * progress;
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);

    final Paint dotPaint = Paint()
      ..color = AnniTheme.accentMagenta.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final double angle = (i * math.pi * 2) / 6;
      final Offset pos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(pos, 2.2 * opacity, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Resilient artwork renderer supporting remote URLs, local file paths,
/// and deterministic gradient vinyl fallback art.
class AnniArtworkWidget extends StatelessWidget {
  const AnniArtworkWidget({
    super.key,
    required this.artworkUrl,
    this.dominantHex = '#8B5CF6',
    this.size = 52.0,
    this.borderRadius = 12.0,
    this.heroTag,
  });

  final String? artworkUrl;
  final String dominantHex;
  final double size;
  final double borderRadius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final Color accent = AnniTheme.parseHexColor(dominantHex);

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withOpacity(0.85),
              AnniTheme.surface2,
              AnniTheme.background,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            LucideIcons.disc,
            size: size * 0.44,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      );
    }

    Widget imageContent;
    if (artworkUrl == null || artworkUrl!.trim().isEmpty) {
      imageContent = fallback();
    } else if (artworkUrl!.startsWith('http://') || artworkUrl!.startsWith('https://')) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: artworkUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (BuildContext context, String url) => AnniShimmerBox(
            width: size,
            height: size,
            borderRadius: borderRadius,
          ),
          errorWidget: (BuildContext context, String url, Object error) => fallback(),
        ),
      );
    } else {
      final File localFile = File(artworkUrl!);
      if (localFile.existsSync()) {
        imageContent = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            localFile,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object err, StackTrace? st) => fallback(),
          ),
        );
      } else {
        imageContent = fallback();
      }
    }

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(tag: heroTag!, child: imageContent);
    }
    return imageContent;
  }
}

/// Reusable rich Track list tile with playing indicator, quality badge, offline badge,
/// favorite burst, and trailing action menu.
class AnniTrackTile extends StatelessWidget {
  const AnniTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isPlaying = false,
    this.onFavoriteToggle,
    this.onDownloadTap,
    this.onMoreTap,
    this.trailing,
    this.indexNumber,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isPlaying;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onMoreTap;
  final Widget? trailing;
  final int? indexNumber;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = AnniTheme.accentMagenta;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            if (indexNumber != null) ...<Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  '$indexNumber',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPlaying ? activeColor : AnniTheme.textTertiary,
                  ),
                ),
              ),
            ],
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnniArtworkWidget(
                  artworkUrl: track.artworkUrl,
                  dominantHex: track.dominantColor,
                  size: 50,
                  borderRadius: 12,
                ),
                if (isPlaying)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.52),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: activeColor, width: 1.5),
                    ),
                    child: const Icon(
                      LucideIcons.barChart2,
                      color: AnniTheme.accentMagenta,
                      size: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (track.isPlayableOffline) ...<Widget>[
                        const DownloadedBadge(),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isPlaying ? activeColor : AnniTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      QualityBadge(label: track.qualityBadge, compact: true),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${track.artist} • ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AnniTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        track.formattedDuration,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AnniTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onFavoriteToggle != null)
              FavoriteBurstButton(
                isFavorite: track.isFavorite,
                onToggle: onFavoriteToggle!,
                size: 20,
              ),
            if (onDownloadTap != null && track.canDownload && !track.isDownloaded)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Download for offline listening',
                icon: const Icon(
                  LucideIcons.download,
                  size: 18,
                  color: AnniTheme.textSecondary,
                ),
                onPressed: onDownloadTap,
              ),
            if (trailing != null)
              trailing!
            else if (onMoreTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  LucideIcons.moreVertical,
                  size: 18,
                  color: AnniTheme.textSecondary,
                ),
                onPressed: onMoreTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper to launch a spring-physics glassmorphic modal bottom sheet.
Future<T?> showAnniBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.68),
    builder: (BuildContext ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: AnniTheme.surface1.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

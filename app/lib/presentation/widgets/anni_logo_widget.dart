import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/anni_theme.dart';

/// Custom vector-painted Anni Music monogram ("A" + eighth note with
/// `#8B5CF6 -> #EC4899 -> #F59E0B` gradient glow and optional pulse animation).
class AnniLogoWidget extends StatefulWidget {
  const AnniLogoWidget({
    super.key,
    this.size = 72.0,
    this.animate = true,
    this.showWordmark = false,
    this.showTagline = false,
  });

  final double size;
  final bool animate;
  final bool showWordmark;
  final bool showTagline;

  @override
  State<AnniLogoWidget> createState() => _AnniLogoWidgetState();
}

class _AnniLogoWidgetState extends State<AnniLogoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
    if (widget.animate) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnniLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.animate && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget monogram = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? child) {
        final double t = widget.animate ? _pulseAnimation.value : 0.5;
        final double scale = 1.0 + (t * 0.045);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AnniTheme.accentViolet.withOpacity(0.28 + (t * 0.18)),
                  blurRadius: widget.size * 0.45,
                  spreadRadius: widget.size * 0.04,
                ),
                BoxShadow(
                  color: AnniTheme.accentMagenta.withOpacity(0.20 + (t * 0.14)),
                  blurRadius: widget.size * 0.65,
                  offset: Offset(0, widget.size * 0.08),
                ),
              ],
            ),
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: AnniMonogramPainter(glowIntensity: t),
            ),
          ),
        );
      },
    );

    if (!widget.showWordmark && !widget.showTagline) {
      return monogram;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        monogram,
        if (widget.showWordmark) ...<Widget>[
          SizedBox(height: widget.size * 0.18),
          ShaderMask(
            shaderCallback: (Rect bounds) =>
                AnniTheme.primaryGradient.createShader(bounds),
            child: Text(
              EnvConfig.appName,
              style: GoogleFonts.outfit(
                fontSize: math.max(22, widget.size * 0.36),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: Colors.white,
              ),
            ),
          ),
        ],
        if (widget.showTagline) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            EnvConfig.tagline,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: AnniTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// CustomPainter that draws the Anni Music monogram:
/// A rounded obsidian squircle emblem with a vibrant gradient border and
/// a geometric letter "A" seamlessly fused with a flowing eighth-note stem & flag.
class AnniMonogramPainter extends CustomPainter {
  const AnniMonogramPainter({this.glowIntensity = 0.5});

  final double glowIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect fullRect = Offset.zero & size;

    // 1. Deep Obsidian Squircle Base
    final RRect baseRRect = RRect.fromRectAndRadius(
      fullRect.deflate(w * 0.04),
      Radius.circular(w * 0.28),
    );

    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF181824),
          Color(0xFF0B0B10),
        ],
      ).createShader(fullRect);

    canvas.drawRRect(baseRRect, basePaint);

    // 2. Subtle Aurora Inner Glow
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.1,
        colors: <Color>[
          AnniTheme.accentViolet.withOpacity(0.22 + glowIntensity * 0.12),
          AnniTheme.accentMagenta.withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(fullRect);
    canvas.drawRRect(baseRRect, auraPaint);

    // 3. Gradient Rim Border
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.032)
      ..shader = AnniTheme.primaryGradient.createShader(fullRect);
    canvas.drawRRect(baseRRect, rimPaint);

    // 4. Primary Gradient Shader for the "A" + Eighth-Note Monogram
    final Shader brandShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AnniTheme.accentViolet,
        AnniTheme.accentMagenta,
        AnniTheme.accentOrange,
      ],
    ).createShader(fullRect);

    final Paint monogramStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.082
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = brandShader;

    // Left slanted leg of "A" -> sweeping up to apex -> vertical right stem of note
    final Path aPath = Path()
      ..moveTo(w * 0.27, h * 0.72)
      ..lineTo(w * 0.48, h * 0.23)
      ..lineTo(w * 0.64, h * 0.66);
    canvas.drawPath(aPath, monogramStroke);

    // Acoustic wave crossbar of the "A"
    final Path crossbarPath = Path()
      ..moveTo(w * 0.34, h * 0.54)
      ..quadraticBezierTo(w * 0.49, h * 0.46, w * 0.64, h * 0.52);
    canvas.drawPath(
      crossbarPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.068
        ..strokeCap = StrokeCap.round
        ..shader = brandShader,
    );

    // Eighth-note flag curving gracefully from the top apex of the "A"
    final Path flagPath = Path()
      ..moveTo(w * 0.48, h * 0.23)
      ..cubicTo(
        w * 0.68,
        h * 0.22,
        w * 0.77,
        h * 0.34,
        w * 0.72,
        h * 0.45,
      );
    canvas.drawPath(
      flagPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.068
        ..strokeCap = StrokeCap.round
        ..shader = brandShader,
    );

    // Filled tilted oval note-head at the bottom-right foot of the "A"
    canvas.save();
    canvas.translate(w * 0.61, h * 0.69);
    canvas.rotate(-0.32);
    final Rect noteHeadRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.19,
      height: h * 0.135,
    );
    canvas.drawOval(
      noteHeadRect,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = brandShader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AnniMonogramPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}

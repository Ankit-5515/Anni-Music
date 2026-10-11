import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/glass_components.dart';

/// Studio-Grade 10-Band Graphic Equalizer & DSP Mastering Suite.
/// Features:
/// - Real-time Spline Frequency Response Curve Painter (-12 dB to +12 dB)
/// - 10 Vertical Band Sliders (`31Hz`, `62Hz`, `125Hz`, `250Hz`, `500Hz`, `1kHz`, `2kHz`, `4kHz`, `8kHz`, `16kHz`)
/// - 8 Audiophile Presets (`Signature Cinema`, `Deep Bass`, `Vocal Clarity`, `Acoustic`, `Electronic`, `Flat`, `Rock`, `Late Night`)
/// - Bass Boost (0–1000), Spatial Virtualizer (0–1000), ReplayGain Normalization, and Crossfade (0–12s)
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EqualizerState eqState = ref.watch(equalizerProvider);
    final EqualizerNotifier eqNotifier = ref.read(equalizerProvider.notifier);
    final UserSettingsEntity settings = ref.watch(userSettingsProvider);
    final UserSettingsNotifier settingsNotifier =
        ref.read(userSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('10-Band Studio Equalizer'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open Android Hardware DSP Panel',
            onPressed: eqNotifier.openSystemEqualizer,
            icon: const Icon(LucideIcons.cpu, size: 20),
          ),
          Row(
            children: <Widget>[
              Text(
                eqState.enabled ? 'ACTIVE' : 'BYPASS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: eqState.enabled
                      ? AnniTheme.success
                      : AnniTheme.textTertiary,
                ),
              ),
              Switch(
                value: eqState.enabled,
                activeColor: AnniTheme.accentMagenta,
                onChanged: (bool val) {
                  HapticFeedback.lightImpact();
                  eqNotifier.setEnabled(val);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1. Preset Selector Chips
            Text(
              'ACOUSTIC PRESETS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AnniTheme.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: eqState.availablePresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final String preset = eqState.availablePresets[index];
                  final bool isSelected = eqState.currentPreset == preset;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      eqNotifier.selectPreset(preset);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AnniTheme.primaryGradient : null,
                        color: isSelected ? null : AnniTheme.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AnniTheme.glassBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          preset,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AnniTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // 2. Real-time Frequency Response Curve Visualizer
            GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const QualityBadge(label: '32-BIT FLOAT DSP'),
                      const SizedBox(width: 8),
                      Text(
                        'Preset: ${eqState.currentPreset}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AnniTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => eqNotifier.selectPreset('Flat'),
                        child: Text(
                          'Reset Flat (0 dB)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AnniTheme.accentMagenta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _FrequencyResponseCurvePainter(
                        bands: eqState.bands,
                        enabled: eqState.enabled,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. 10-Band Vertical Sliders (31Hz to 16kHz)
                  SizedBox(
                    height: 235,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(
                        kEqualizerBandLabels.length,
                        (int idx) {
                          final double dbVal =
                              idx < eqState.bands.length ? eqState.bands[idx] : 0.0;
                          final String dbText = dbVal >= 0
                              ? '+${dbVal.toStringAsFixed(1)}'
                              : dbVal.toStringAsFixed(1);

                          return Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  dbText,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: dbVal.abs() > 0.2
                                        ? AnniTheme.accentMagenta
                                        : AnniTheme.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3.5,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6.5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                          overlayRadius: 12,
                                        ),
                                      ),
                                      child: Slider(
                                        value: dbVal.clamp(-12.0, 12.0),
                                        min: -12.0,
                                        max: 12.0,
                                        onChanged: eqState.enabled
                                            ? (double next) {
                                                HapticFeedback.selectionClick();
                                                eqNotifier.setBandGain(
                                                  idx,
                                                  next,
                                                );
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  kEqualizerBandLabels[idx],
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    color: AnniTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Rotary / Dials for Bass Boost & Spatial Virtualizer
            Row(
              children: <Widget>[
                Expanded(
                  child: _DspControlCard(
                    title: 'Bass Boost',
                    subtitle: 'Sub-harmonic punch',
                    icon: LucideIcons.speaker,
                    value: eqState.bassBoostStrength / 1000.0,
                    labelValue: '${(eqState.bassBoostStrength / 10).round()}%',
                    accentColor: AnniTheme.accentViolet,
                    onChanged: (double v) {
                      eqNotifier.setBassBoost((v * 1000).round());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DspControlCard(
                    title: 'Virtualizer',
                    subtitle: '3D spatial soundstage',
                    icon: LucideIcons.headphones,
                    value: eqState.virtualizerStrength / 1000.0,
                    labelValue: '${(eqState.virtualizerStrength / 10).round()}%',
                    accentColor: AnniTheme.accentOrange,
                    onChanged: (double v) {
                      eqNotifier.setVirtualizer((v * 1000).round());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. ReplayGain Normalization & Crossfade (0-12s)
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'ReplayGain Loudness Normalization',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Automatically matches perceived volume across local & streamed tracks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AnniTheme.textSecondary,
                      ),
                    ),
                    activeColor: AnniTheme.accentMagenta,
                    value: eqState.replayGainEnabled,
                    onChanged: (bool val) {
                      HapticFeedback.selectionClick();
                      eqNotifier.setReplayGain(val);
                    },
                  ),
                  const Divider(height: 24),
                  Row(
                    children: <Widget>[
                      const Icon(
                        LucideIcons.gitMerge,
                        size: 18,
                        color: AnniTheme.accentViolet,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Crossfade Transition',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      QualityBadge(
                        label: settings.crossfadeSeconds == 0
                            ? 'OFF (GAPLESS)'
                            : '${settings.crossfadeSeconds}s FADE',
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.crossfadeSeconds.toDouble(),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    label: '${settings.crossfadeSeconds}s',
                    onChanged: (double val) {
                      HapticFeedback.selectionClick();
                      settingsNotifier.setCrossfadeSeconds(val.round());
                    },
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

class _DspControlCard extends StatelessWidget {
  const _DspControlCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.labelValue,
    required this.accentColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final String labelValue;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                labelValue,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AnniTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 74,
              height: 74,
              child: CustomPaint(
                painter: _RotaryDialPainter(
                  value: value,
                  accentColor: accentColor,
                ),
                child: Center(
                  child: Text(
                    labelValue,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnniTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Slider(
            value: value.clamp(0.0, 1.0),
            activeColor: accentColor,
            onChanged: (double v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _RotaryDialPainter extends CustomPainter {
  const _RotaryDialPainter({
    required this.value,
    required this.accentColor,
  });

  final double value;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 6;
    const double startAngle = math.pi * 0.75;
    const double sweepTotal = math.pi * 1.5;

    final Paint trackPaint = Paint()
      ..color = AnniTheme.surface3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    final Paint activePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * value.clamp(0.0, 1.0),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RotaryDialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.accentColor != accentColor;
}

class _FrequencyResponseCurvePainter extends CustomPainter {
  const _FrequencyResponseCurvePainter({
    required this.bands,
    required this.enabled,
  });

  final List<double> bands;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double midY = h / 2;

    // 0dB reference grid line
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), gridPaint);
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), gridPaint);

    if (bands.isEmpty) return;

    final List<Offset> points = <Offset>[];
    for (int i = 0; i < bands.length; i++) {
      final double x = (i / (bands.length - 1)) * w;
      final double normalized = (bands[i].clamp(-12.0, 12.0) / 12.0);
      final double y = midY - (normalized * (h * 0.42));
      points.add(Offset(x, y));
    }

    final Path curvePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double controlX = (p0.dx + p1.dx) / 2;
      curvePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final Path fillPath = Path.from(curvePath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            (enabled ? AnniTheme.accentMagenta : AnniTheme.textTertiary)
                .withOpacity(0.32),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      curvePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..shader = enabled
            ? AnniTheme.primaryGradient.createShader(Offset.zero & size)
            : null
        ..color = enabled ? Colors.white : AnniTheme.textTertiary,
    );

    for (final Offset pt in points) {
      canvas.drawCircle(
        pt,
        3.5,
        Paint()..color = enabled ? Colors.white : AnniTheme.textTertiary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyResponseCurvePainter oldDelegate) =>
      oldDelegate.bands != bands || oldDelegate.enabled != enabled;
}

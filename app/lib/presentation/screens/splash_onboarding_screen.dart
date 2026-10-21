import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../widgets/anni_logo_widget.dart';
import '../widgets/glass_components.dart';

/// Animated Splash & 3-step interactive Onboarding experience for Anni Music.
class SplashOnboardingScreen extends ConsumerStatefulWidget {
  const SplashOnboardingScreen({
    super.key,
    this.skipSplashDelay = false,
  });

  final bool skipSplashDelay;

  @override
  ConsumerState<SplashOnboardingScreen> createState() =>
      _SplashOnboardingScreenState();
}

class _SplashOnboardingScreenState
    extends ConsumerState<SplashOnboardingScreen> {
  final PageController _pageController = PageController();
  bool _showOnboarding = false;
  int _currentPage = 0;
  Timer? _splashTimer;

  static const List<_OnboardingSlideData> _slides = <_OnboardingSlideData>[
    _OnboardingSlideData(
      badge: 'HYBRID AUDIO ARCHITECTURE',
      title: 'Lossless Local & Cloud Harmony',
      subtitle:
          'Index 10,000+ on-device FLAC, WAV, and MP3 files alongside high-resolution legal streaming in one unified audiophile library.',
      icon: LucideIcons.hardDrive,
      accentColor: AnniTheme.accentViolet,
      highlights: <String>['FLAC 24-bit', '10,000+ Local Songs', 'Instant A–Z Index'],
    ),
    _OnboardingSlideData(
      badge: 'PRECISION ACOUSTICS',
      title: 'Studio-Grade Audio Engine',
      subtitle:
          'Sculpt every frequency with our 10-band graphic equalizer, custom response curve, gapless playback, crossfade, and ReplayGain.',
      icon: LucideIcons.sliders,
      accentColor: AnniTheme.accentMagenta,
      highlights: <String>['10-Band EQ', '0–12s Crossfade', 'ReplayGain DSP'],
    ),
    _OnboardingSlideData(
      badge: '100% LEGAL & OPEN',
      title: 'Legal Streaming & Offline Freedom',
      subtitle:
          'Stream and download Creative Commons & Public Domain masters from Jamendo, Internet Archive, plus official YouTube IFrame sessions.',
      icon: LucideIcons.globe,
      accentColor: AnniTheme.accentOrange,
      highlights: <String>['Jamendo CC', 'Internet Archive', 'Cloud Delta Sync'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.skipSplashDelay) {
      _showOnboarding = true;
    } else {
      _splashTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() => _showOnboarding = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextSlideOrFinish() {
    HapticFeedback.lightImpact();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.go('/auth');
    }
  }

  void _continueAsGuest() {
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnniTheme.background,
      body: Stack(
        children: <Widget>[
          // Ambient aurora radial backdrop
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AnniTheme.accentViolet.withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AnniTheme.accentMagenta.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              child: !_showOnboarding
                  ? _buildSplashView()
                  : _buildOnboardingCarousel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplashView() {
    return Center(
      key: const ValueKey<String>('splash_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AnniLogoWidget(
            size: 108,
            animate: true,
            showWordmark: true,
            showTagline: true,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AnniTheme.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(AnniTheme.accentMagenta),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingCarousel() {
    return Column(
      key: const ValueKey<String>('onboarding_carousel'),
      children: <Widget>[
        // Top Header with Mini Logo + Skip button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: <Widget>[
              const AnniLogoWidget(size: 38, animate: false),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Anni Music',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AnniTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Your music. Your world.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AnniTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: _continueAsGuest,
                child: Text(
                  'Skip to App',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AnniTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3-Slide Interactive PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (int idx) {
              setState(() => _currentPage = idx);
            },
            itemBuilder: (BuildContext context, int index) {
              final _OnboardingSlideData slide = _slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                    // Visual Showcase Card
                    Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            slide.accentColor.withOpacity(0.32),
                            AnniTheme.surface2.withOpacity(0.6),
                          ],
                        ),
                        border: Border.all(
                          color: slide.accentColor.withOpacity(0.45),
                          width: 1.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: slide.accentColor.withOpacity(0.26),
                            blurRadius: 42,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          slide.icon,
                          size: 68,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: slide.accentColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: slide.accentColor.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        slide.badge,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: slide.accentColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AnniTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        height: 1.5,
                        color: AnniTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: slide.highlights
                          .map((String pill) => QualityBadge(label: pill))
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
            },
          ),
        ),

        // Smooth Page Indicators & Bottom CTAs
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_slides.length, (int i) {
                  final bool isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: isActive ? AnniTheme.primaryGradient : null,
                      color: isActive ? null : AnniTheme.surface3,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AnniTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AnniTheme.accentMagenta.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _nextSlideOrFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _currentPage < _slides.length - 1
                              ? 'Next Feature'
                              : 'Sign In / Create Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          LucideIcons.arrowRight,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _continueAsGuest,
                  icon: const Icon(LucideIcons.headphones, size: 17),
                  label: Text(
                    'Continue as Guest (Local + Free Streams)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AnniTheme.textPrimary,
                    side: const BorderSide(color: AnniTheme.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.highlights,
  });

  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> highlights;
}

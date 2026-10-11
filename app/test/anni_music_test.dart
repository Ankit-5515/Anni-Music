import 'package:anni_music/core/theme/anni_theme.dart';
import 'package:anni_music/data/providers/app_providers.dart';
import 'package:anni_music/presentation/screens/splash_onboarding_screen.dart';
import 'package:anni_music/presentation/widgets/anni_logo_widget.dart';
import 'package:anni_music/presentation/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1. LRC Time-Synced Lyrics Parser Tests', () {
    test('parses timestamped LRC lines and sorts chronologically', () {
      const String sampleLrc = '''
[ar:Ketsa]
[ti:Midnight Aurora]
[00:12.50] Second line in song
[00:04.20] First line in song
[01:05.00] Chorus drop
''';

      final List<LrcLine> lines = LrcParser.parse(sampleLrc);
      expect(lines.length, 3);
      expect(lines[0].text, 'First line in song');
      expect(lines[0].timestamp, const Duration(seconds: 4, milliseconds: 200));
      expect(lines[1].text, 'Second line in song');
      expect(lines[2].text, 'Chorus drop');
      expect(lines[2].timestamp, const Duration(minutes: 1, seconds: 5));
    });

    test('findActiveLineIndex resolves current lyric index accurately', () {
      final List<LrcLine> lines = LrcParser.parse('''
[00:00.00] Intro
[00:10.00] Verse 1
[00:20.00] Chorus
''');

      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 5)),
        0,
      );
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 12)),
        1,
      );
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 25)),
        2,
      );
    });
  });

  group('2. Extended M3U8 Playlist Export & Import Tests', () {
    test('exports Playlist to .m3u8 and re-imports matching tracks', () {
      final DateTime now = DateTime(2026, 1, 1);
      final Playlist original = Playlist(
        id: 'pl_test_1',
        name: 'Obsidian Synth Mix',
        description: 'Lossless test mix',
        isPublic: true,
        tracks: kSeededLegalCatalog.take(3).toList(),
        createdAt: now,
        updatedAt: now,
      );

      final String m3uText = original.toM3u();
      expect(m3uText, contains('#EXTM3U'));
      expect(m3uText, contains('#PLAYLIST:Obsidian Synth Mix'));
      expect(m3uText, contains('Midnight Aurora'));

      final Playlist reimported = Playlist.fromM3u(
        m3uContent: m3uText,
        fallbackName: 'Fallback',
        knownTracks: kSeededLegalCatalog,
      );

      expect(reimported.name, 'Obsidian Synth Mix');
      expect(reimported.trackCount, 3);
      expect(reimported.tracks.first.title, 'Midnight Aurora');
      expect(reimported.tracks.first.artist, 'Ketsa & Neon Drift');
    });
  });

  group('3. Track Entity Serialization & Deterministic Waveform Tests', () {
    test('serializes and deserializes Track toJson/fromJson losslessly', () {
      final Track track = kSeededLegalCatalog.first.copyWith(
        isFavorite: true,
        isDownloaded: true,
      );

      final Map<String, dynamic> json = track.toJson();
      final Track restored = Track.fromJson(json);

      expect(restored.id, track.id);
      expect(restored.title, track.title);
      expect(restored.artist, track.artist);
      expect(restored.source, TrackSource.jamendo);
      expect(restored.qualityBadge, 'FLAC');
      expect(restored.isFavorite, isTrue);
      expect(restored.isDownloaded, isTrue);
      expect(restored.formattedDuration, '03:34');
      expect(restored.effectiveWaveform.length, 48);
    });
  });

  group('4. Equalizer Presets, Playback & Theme Token Tests', () {
    test('10-band Equalizer presets have 10 frequency bands within [-12, 12] dB', () {
      expect(kEqualizerFrequenciesHz.length, 10);
      expect(kEqualizerBandLabels.length, 10);
      for (final MapEntry<String, List<double>> entry
          in kEqualizerPresets.entries) {
        expect(
          entry.value.length,
          10,
          reason: 'Preset ${entry.key} must have 10 bands',
        );
        for (final double gain in entry.value) {
          expect(gain, inInclusiveRange(-12.0, 12.0));
        }
      }
    });

    test('UserSettingsEntity & AnniTheme hex parser work accurately', () {
      const UserSettingsEntity settings = UserSettingsEntity(
        themeMode: 'amoled',
        crossfadeSeconds: 6,
      );
      expect(settings.isAmoled, isTrue);
      expect(settings.isLight, isFalse);

      final Color parsed = AnniTheme.parseHexColor('#EC4899');
      expect(parsed, const Color(0xFFEC4899));
    });
  });

  group('5. Presentation UI Widget Rendering Tests', () {
    testWidgets('renders AnniLogoWidget, QualityBadge, and GradientPlayButton', (
      WidgetTester tester,
    ) async {
      bool playTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const AnniLogoWidget(
                  size: 64,
                  animate: false,
                  showWordmark: true,
                  showTagline: true,
                ),
                const QualityBadge(label: 'FLAC 24-BIT'),
                const DownloadedBadge(showLabel: true),
                GradientPlayButton(
                  isPlaying: false,
                  onPressed: () => playTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Anni Music'), findsOneWidget);
      expect(find.text('Your music. Your world.'), findsOneWidget);
      expect(find.text('FLAC 24-BIT'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);

      await tester.tap(find.byType(GradientPlayButton));
      await tester.pump();
      expect(playTapped, isTrue);
    });

    testWidgets('renders SplashOnboardingScreen carousel slides', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashOnboardingScreen(skipSplashDelay: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lossless Local & Cloud Harmony'), findsOneWidget);
      expect(find.text('Next Feature'), findsOneWidget);
    });
  });
}

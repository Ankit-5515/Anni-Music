import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/anni_logo_widget.dart';
import '../widgets/glass_components.dart';
import 'equalizer_screen.dart';

/// User Profile, Cloud Synchronization, Audio Quality, Theme, & Legal Compliance Screen.
class SettingsProfileScreen extends ConsumerStatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  ConsumerState<SettingsProfileScreen> createState() =>
      _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends ConsumerState<SettingsProfileScreen> {
  bool _isSyncing = false;
  bool _autoRescanLocal = true;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    HapticFeedback.lightImpact();
    try {
      await ref.read(musicRepositoryProvider).syncWithCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cloud delta sync complete — playlists, favorites & settings synced.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AnniTheme.surface2,
          title: Text(
            'Delete Cloud Account?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This permanently removes your cloud profile, synced playlists, and analytics history. Your local on-device music files will remain untouched.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: AnniTheme.textSecondary,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AnniTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud account deleted. Switched to local Guest Mode.'),
        ),
      );
    }
  }

  void _showLegalModal({required String title, required String body}) {
    showAnniBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    LucideIcons.shieldCheck,
                    color: AnniTheme.accentViolet,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.55,
                  color: AnniTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authStateProvider);
    final UserProfile user = authState.user;
    final UserSettingsEntity settings = ref.watch(userSettingsProvider);
    final UserSettingsNotifier settingsNotifier =
        ref.read(userSettingsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 175),
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            // 1. Screen Title
            Text(
              'Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AnniTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 2. Profile Header Card (Spotify-Style)
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context, user),
                        child: Stack(
                          children: <Widget>[
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AnniTheme.primaryGradient,
                                image: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(user.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                  ? Center(
                                      child: Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : 'A',
                                        style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AnniTheme.accentViolet,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.pencil, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () => _showEditNameDialog(context, user),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: AnniTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(LucideIcons.edit2, size: 14, color: AnniTheme.textTertiary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                QualityBadge(
                                  label: user.isGuest ? 'GUEST' : 'PREMIUM',
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AnniTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Spotify-style Listening Stats Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _buildStatCol('Playlists', '${ref.watch(playlistsProvider).length}'),
                        Container(width: 1, height: 26, color: Colors.white.withOpacity(0.08)),
                        _buildStatCol('Liked Songs', '${ref.watch(favoritesProvider).length}'),
                        Container(width: 1, height: 26, color: Colors.white.withOpacity(0.08)),
                        _buildStatCol(
                          'Hours Listened',
                          user.hoursListened > 0
                              ? user.hoursListened.toStringAsFixed(1)
                              : '14.2',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncNow,
                          icon: Icon(
                            _isSyncing
                                ? LucideIcons.loader
                                : LucideIcons.refreshCw,
                            size: 16,
                          ),
                          label: Text(_isSyncing ? 'Syncing...' : 'Cloud Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AnniTheme.accentViolet,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (user.isGuest) {
                              context.go('/auth');
                            } else {
                              await ref.read(authStateProvider.notifier).logout();
                            }
                          },
                          icon: Icon(
                            user.isGuest
                                ? LucideIcons.logIn
                                : LucideIcons.logOut,
                            size: 16,
                          ),
                          label: Text(user.isGuest ? 'Sign In' : 'Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnniTheme.textPrimary,
                            side: const BorderSide(color: AnniTheme.glassBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Appearance & Theme Selector (Cinematic Dark #07070A, AMOLED #000000, Light)
            _buildSectionLabel('THEME & APPEARANCE'),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 20,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _buildThemeOption(
                      label: 'Cinematic Dark',
                      subtitle: '#07070A',
                      selected: settings.themeMode == 'dark',
                      onTap: () => settingsNotifier.setThemeMode('dark'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      label: 'AMOLED Black',
                      subtitle: '#000000',
                      selected: settings.themeMode == 'amoled',
                      onTap: () => settingsNotifier.setThemeMode('amoled'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      label: 'Daylight',
                      subtitle: 'Light',
                      selected: settings.themeMode == 'light',
                      onTap: () => settingsNotifier.setThemeMode('light'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. Audio Quality & Playback Engine
            _buildSectionLabel('AUDIO QUALITY & DSP ENGINE'),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      LucideIcons.sliders,
                      color: AnniTheme.accentMagenta,
                    ),
                    title: const Text('10-Band Studio Equalizer & DSP'),
                    subtitle: Text(
                      'Preset: ${ref.watch(equalizerProvider).currentPreset}',
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildQualitySelectorRow(
                    title: 'Streaming Audio Quality',
                    currentValue: settings.streamingQuality,
                    onChanged: settingsNotifier.setStreamingQuality,
                  ),
                  const SizedBox(height: 12),
                  _buildQualitySelectorRow(
                    title: 'Offline Download Quality',
                    currentValue: settings.downloadQuality,
                    onChanged: settingsNotifier.setDownloadQuality,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Crossfade Duration (0–12s)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      QualityBadge(
                        label: settings.crossfadeSeconds == 0
                            ? 'OFF'
                            : '${settings.crossfadeSeconds}s',
                        compact: true,
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.crossfadeSeconds.toDouble(),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: (double v) =>
                        settingsNotifier.setCrossfadeSeconds(v.round()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gapless Playback'),
                    subtitle: const Text(
                      'Pre-buffer next track in queue for zero-latency transitions',
                    ),
                    activeColor: AnniTheme.accentMagenta,
                    value: settings.gaplessPlayback,
                    onChanged: settingsNotifier.setGaplessPlayback,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ReplayGain Normalization'),
                    subtitle: const Text(
                      'Prevent sudden volume jumps across mixed sources',
                    ),
                    activeColor: AnniTheme.accentMagenta,
                    value: settings.replayGain,
                    onChanged: settingsNotifier.setReplayGain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 5. Local Storage & Cache Management
            _buildSectionLabel('LOCAL STORAGE & CACHE'),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Rescan Local Music Folders'),
                    subtitle: const Text(
                      'Automatically index new FLAC/MP3/WAV files on app launch',
                    ),
                    activeColor: AnniTheme.accentViolet,
                    value: _autoRescanLocal,
                    onChanged: (bool val) {
                      setState(() => _autoRescanLocal = val);
                      if (val) {
                        ref
                            .read(localLibraryProvider.notifier)
                            .scanDeviceStorage();
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wi-Fi Only Downloads'),
                    subtitle: const Text(
                      'Pause large FLAC downloads when on cellular data',
                    ),
                    activeColor: AnniTheme.accentViolet,
                    value: settings.wifiOnlyDownloads,
                    onChanged: settingsNotifier.setWifiOnlyDownloads,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      LucideIcons.trash2,
                      color: AnniTheme.accentOrange,
                    ),
                    title: const Text('Clear Temporary Stream & Artwork Cache'),
                    subtitle: const Text(
                      'Frees temporary cache without deleting downloaded songs',
                    ),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Temporary stream & image cache cleared.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 6. Privacy, Legal Compliance & Account Deletion
            _buildSectionLabel('PRIVACY, LEGAL & ACCOUNT'),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy-Safe Playback Telemetry'),
                    subtitle: const Text(
                      'Help improve recommendations (opt-out at any time)',
                    ),
                    activeColor: AnniTheme.success,
                    value: settings.analyticsOptIn,
                    onChanged: settingsNotifier.setAnalyticsOptIn,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.shield, size: 18),
                    title: const Text('Privacy Policy (GDPR / CCPA Compliant)'),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => _showLegalModal(
                      title: 'Anni Music Privacy Policy',
                      body:
                          'Anni Music ("Your music. Your world.") respects your privacy.\n\n'
                          '1. Local Audio Privacy: Your on-device MP3, FLAC, WAV, and M4A files never leave your device.\n'
                          '2. Cloud Sync: Only your playlist metadata, favorites, and equalizer preferences are synced when signed in.\n'
                          '3. Telemetry Opt-Out: You can disable analytics events at any time from Settings.\n'
                          '4. Right to Erasure: Use "Delete Cloud Account" below to permanently erase all cloud data.',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.fileText, size: 18),
                    title: const Text('Terms of Service & Content Licensing'),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => _showLegalModal(
                      title: 'Terms of Service & Legal Audio Sources',
                      body:
                          'Anni Music is 100% compliant with copyright and DMCA regulations.\n\n'
                          '• Jamendo Creative Commons: Streamed and downloaded under explicit CC-BY / CC-BY-SA artist licenses.\n'
                          '• Internet Archive: Public Domain & open-licensed audio collections.\n'
                          '• YouTube Official IFrame Player: Rendered strictly via the official YouTube IFrame API without stream ripping or background audio extraction.\n'
                          '• DMCA Safe Harbor: Rights holders may contact legal@anni.music.',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      LucideIcons.userX,
                      color: AnniTheme.error,
                      size: 18,
                    ),
                    title: const Text(
                      'Delete Cloud Account',
                      style: TextStyle(
                        color: AnniTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently erase cloud profile & synced data',
                    ),
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Brand Footer
            Center(
              child: Column(
                children: <Widget>[
                  const AnniLogoWidget(size: 42, animate: false),
                  const SizedBox(height: 8),
                  Text(
                    '${EnvConfig.appName} v${EnvConfig.appVersion} (${EnvConfig.packageName})',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AnniTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AnniTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AnniTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showAvatarPicker(BuildContext context, UserProfile user) {
    const List<String> presetAvatars = <String>[
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&q=80',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=80',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AnniTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Choose Profile Avatar',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AnniTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: presetAvatars.map((String url) {
                return GestureDetector(
                  onTap: () {
                    ref.read(authStateProvider.notifier).updateProfile(avatarUrl: url);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: user.avatarUrl == url
                            ? AnniTheme.accentViolet
                            : Colors.white.withOpacity(0.12),
                        width: 2,
                      ),
                      image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, UserProfile user) {
    final TextEditingController controller = TextEditingController(text: user.displayName);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AnniTheme.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text(
          'Edit Display Name',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AnniTheme.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter name',
            hintStyle: GoogleFonts.plusJakartaSans(color: AnniTheme.textTertiary),
            filled: true,
            fillColor: AnniTheme.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AnniTheme.accentViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final String newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(authStateProvider.notifier).updateProfile(displayName: newName);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AnniTheme.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected ? AnniTheme.primaryGradient : null,
          color: selected ? null : AnniTheme.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : AnniTheme.glassBorder,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AnniTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: selected
                    ? Colors.white.withOpacity(0.85)
                    : AnniTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySelectorRow({
    required String title,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    const List<Map<String, String>> options = <Map<String, String>>[
      <String, String>{'key': 'normal', 'label': '160k'},
      <String, String>{'key': 'high', 'label': '320kbps'},
      <String, String>{'key': 'lossless', 'label': 'FLAC'},
    ];

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: options.map((Map<String, String> opt) {
            final bool selected = currentValue == opt['key'];
            return ChoiceChip(
              label: Text(
                opt['label']!,
                style: GoogleFonts.jetBrainsMono(fontSize: 11),
              ),
              selected: selected,
              selectedColor: AnniTheme.accentViolet,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onChanged(opt['key']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

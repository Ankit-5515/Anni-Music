import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import 'glass_components.dart';

/// Modal sheet for editing local ID3 / audio metadata tags (Title, Artist, Album,
/// Genre, Release Year, Custom Artwork) and setting the track as the Android device ringtone.
class TagEditorSheet extends ConsumerStatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.track,
  });

  final Track track;

  static Future<Track?> show(BuildContext context, Track track) {
    return showAnniBottomSheet<Track>(
      context: context,
      builder: (BuildContext ctx) => TagEditorSheet(track: track),
    );
  }

  @override
  ConsumerState<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<TagEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _genreController;
  late final TextEditingController _yearController;

  String? _selectedArtworkPath;
  bool _isSaving = false;
  bool _isSettingRingtone = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album);
    _genreController = TextEditingController(text: widget.track.genre);
    _yearController = TextEditingController(
      text: widget.track.releaseYear?.toString() ?? '2025',
    );
    _selectedArtworkPath = widget.track.artworkUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickArtworkImage() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedArtworkPath = result.files.single.path;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTags() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final int? parsedYear = int.tryParse(_yearController.text.trim());
      final Track updated = await ref.read(localLibraryProvider.notifier).updateTrackTags(
            track: widget.track.copyWith(artworkUrl: _selectedArtworkPath),
            title: _titleController.text.trim(),
            artist: _artistController.text.trim(),
            album: _albumController.text.trim(),
            genre: _genreController.text.trim(),
            releaseYear: parsedYear,
          );

      ref.read(playbackStateProvider.notifier).updateCurrentTrackMetadata(updated);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio metadata tags updated successfully.'),
        ),
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tags: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleSetAsRingtone() async {
    setState(() => _isSettingRingtone = true);
    try {
      final bool success = await ref
          .read(localLibraryProvider.notifier)
          .setTrackAsRingtone(widget.track);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '"${widget.track.title}" set as phone ringtone!'
                : 'Grant Write System Settings permission or use a downloaded/local audio file.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set ringtone: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSettingRingtone = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 8, 22, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AnniTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.tags,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ID3 Tag Editor & Ringtone',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AnniTheme.textPrimary,
                        ),
                      ),
                      Text(
                        widget.track.localFilePath ?? widget.track.source.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AnniTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Artwork Picker + Quick Ringtone CTA
            Row(
              children: <Widget>[
                GestureDetector(
                  onTap: _pickArtworkImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: <Widget>[
                      AnniArtworkWidget(
                        artworkUrl: _selectedArtworkPath,
                        dominantHex: widget.track.dominantColor,
                        size: 76,
                        borderRadius: 16,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AnniTheme.accentViolet,
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 13,
                          color: Colors.white,
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
                      OutlinedButton.icon(
                        onPressed: _pickArtworkImage,
                        icon: const Icon(LucideIcons.image, size: 16),
                        label: const Text('Change Cover Artwork'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AnniTheme.textPrimary,
                          side: const BorderSide(color: AnniTheme.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSettingRingtone ? null : _handleSetAsRingtone,
                          icon: _isSettingRingtone
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(LucideIcons.bellRing, size: 16),
                          label: const Text('Set as Phone Ringtone'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AnniTheme.surface3,
                            foregroundColor: AnniTheme.accentOrange,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AnniTheme.accentOrange.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _buildField(
              label: 'Track Title',
              controller: _titleController,
              icon: LucideIcons.music,
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'Artist',
              controller: _artistController,
              icon: LucideIcons.mic2,
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Artist is required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'Album',
              controller: _albumController,
              icon: LucideIcons.disc,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _buildField(
                    label: 'Genre',
                    controller: _genreController,
                    icon: LucideIcons.sparkles,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildField(
                    label: 'Release Year',
                    controller: _yearController,
                    icon: LucideIcons.calendar,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AnniTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTags,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.check, size: 18, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Saving Metadata...' : 'Save Metadata Tags',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AnniTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AnniTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 17, color: AnniTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

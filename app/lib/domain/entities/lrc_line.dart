import 'package:equatable/equatable.dart';

/// Single time-synchronized lyric line from an `.lrc` file or remote lyrics payload.
class LrcLine extends Equatable {
  const LrcLine({
    required this.timestamp,
    required this.text,
  });

  final Duration timestamp;
  final String text;

  int get milliseconds => timestamp.inMilliseconds;

  @override
  List<Object?> get props => <Object?>[timestamp, text];
}

/// Utility for parsing standard and enhanced `.lrc` time-synced lyrics and resolving active lines.
class LrcParser {
  const LrcParser._();

  static final RegExp _timeTagRegex = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  /// Parses raw LRC string (`[mm:ss.xx] Lyric text`) into a chronologically sorted list of [LrcLine].
  /// If plain unsynced lyrics are passed, assigns synthetic 4-second intervals so karaoke view still scrolls cleanly.
  static List<LrcLine> parse(String rawLrc) {
    if (rawLrc.trim().isEmpty) {
      return const <LrcLine>[];
    }

    final List<LrcLine> syncedLines = <LrcLine>[];
    final List<String> plainLines = <String>[];

    for (final String rawLine in rawLrc.split(RegExp(r'\r?\n'))) {
      final String trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      // Skip metadata tags like [ar:Artist], [ti:Title], [al:Album]
      if (RegExp(r'^\[(ar|ti|al|au|by|offset|re|ve):', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }

      final Iterable<RegExpMatch> matches = _timeTagRegex.allMatches(trimmed);
      if (matches.isNotEmpty) {
        final String lyricText = trimmed.replaceAll(_timeTagRegex, '').trim();
        for (final RegExpMatch match in matches) {
          final int minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
          final int seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
          final String fracStr = match.group(3) ?? '0';
          final int millis = fracStr.length == 2
              ? (int.tryParse(fracStr) ?? 0) * 10
              : fracStr.length == 1
                  ? (int.tryParse(fracStr) ?? 0) * 100
                  : int.tryParse(fracStr) ?? 0;

          syncedLines.add(
            LrcLine(
              timestamp: Duration(
                minutes: minutes,
                seconds: seconds,
                milliseconds: millis,
              ),
              text: lyricText.isEmpty ? '♪' : lyricText,
            ),
          );
        }
      } else {
        plainLines.add(trimmed);
      }
    }

    if (syncedLines.isNotEmpty) {
      syncedLines.sort((LrcLine a, LrcLine b) => a.timestamp.compareTo(b.timestamp));
      return syncedLines;
    }

    // Fallback for plain text lyrics: space lines every 4 seconds
    return List<LrcLine>.generate(
      plainLines.length,
      (int index) => LrcLine(
        timestamp: Duration(seconds: index * 4),
        text: plainLines[index],
      ),
    );
  }

  /// Binary-searches the active lyric line index for the given playback [position].
  static int findActiveLineIndex(List<LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    int activeIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }
}

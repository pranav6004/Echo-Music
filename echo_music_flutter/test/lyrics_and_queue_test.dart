import 'package:echo_music/lyrics/lyrics_utils.dart';
import 'package:echo_music/playback/media_metadata.dart';
import 'package:echo_music/playback/queues.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LyricsUtils LRC & Synced Parsing', () {
    test('isSynced detects standard LRC timestamps and ignores section headers', () {
      expect(LyricsUtils.isSynced('[00:12.34] Welcome to Resona'), isTrue);
      expect(LyricsUtils.isSynced('[01:05.123] Second line'), isTrue);
      expect(LyricsUtils.isSynced('[Verse 1]\nSome unsynced text'), isFalse);
      expect(LyricsUtils.isSynced('Just plain lyric text without brackets'), isFalse);
    });

    test('parseLyrics parses standard timestamps into sorted millisecond entries', () {
      const lrc = '''[00:05.00] Intro beat
[00:15.50] Verse starts here
[00:30.00] Chorus arrives''';
      final entries = LyricsUtils.parseLyrics(lrc);
      expect(entries.length, equals(3));
      expect(entries[0].time, equals(5000));
      expect(entries[0].text, equals('Intro beat'));
      expect(entries[1].time, equals(15500));
      expect(entries[1].text, equals('Verse starts here'));
      expect(entries[2].time, equals(30000));
      expect(entries[2].text, equals('Chorus arrives'));
    });

    test('parseLyrics correctly handles multi-timestamp repeated lines', () {
      const lrc = '[00:10.00][00:40.00] Repeated refrain';
      final entries = LyricsUtils.parseLyrics(lrc);
      expect(entries.length, equals(2));
      expect(entries[0].time, equals(10000));
      expect(entries[0].text, equals('Repeated refrain'));
      expect(entries[1].time, equals(40000));
      expect(entries[1].text, equals('Repeated refrain'));
    });

    test('parseLyrics decodes HTML entities in lyric text', () {
      const lrc = '[00:02.00] Rock &amp; Roll &#39;n&#39; &quot;Fun&quot;';
      final entries = LyricsUtils.parseLyrics(lrc);
      expect(entries.length, equals(1));
      expect(entries[0].text, equals("Rock & Roll 'n' \"Fun\""));
    });
  });

  group('QueueStatus Index Re-pointing & Filtering', () {
    test('filtered maintains current item index when preceding items are removed', () {
      final items = [
        const MediaMetadata(id: '1', title: 'Song 1'),
        const MediaMetadata(id: '2', title: 'Song 2'),
        const MediaMetadata(id: '3', title: 'Song 3 (Current)'),
        const MediaMetadata(id: '4', title: 'Song 4'),
      ];

      final queue = QueueStatus(
        title: 'Main Queue',
        items: items,
        mediaItemIndex: 2,
      );

      final filtered = queue.filtered((m) => m.id != '1');
      expect(filtered.items.length, equals(3));
      expect(filtered.mediaItemIndex, equals(1));
      expect(filtered.items[filtered.mediaItemIndex].id, equals('3'));
    });

    test('filtered gracefully clamps index when all items are filtered out', () {
      final items = [
        const MediaMetadata(id: '1', title: 'Song 1'),
      ];

      final queue = QueueStatus(
        title: 'Empty Queue',
        items: items,
        mediaItemIndex: 0,
      );

      final filtered = queue.filtered((m) => false);
      expect(filtered.items.isEmpty, isTrue);
      expect(filtered.mediaItemIndex, equals(0));
    });
  });
}

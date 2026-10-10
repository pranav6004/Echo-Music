import 'package:resona/data/download_manager.dart';
import 'package:resona/innertube/models/yt_item.dart';
import 'package:resona/lyrics/lyrics_utils.dart';
import 'package:resona/playback/media_metadata.dart';
import 'package:resona/playback/queues.dart';
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

    test('findCurrentLineIndex locates active lyric line with 300ms look-ahead', () {
      final entries = [
        const LyricsEntry(1000, 'Line 1'),
        const LyricsEntry(5000, 'Line 2'),
        const LyricsEntry(10000, 'Line 3'),
      ];
      expect(LyricsUtils.findCurrentLineIndex(entries, 0), equals(-1));
      expect(LyricsUtils.findCurrentLineIndex(entries, 1200), equals(0));
      expect(LyricsUtils.findCurrentLineIndex(entries, 4800), equals(1));
      expect(LyricsUtils.findCurrentLineIndex(entries, 12000), equals(2));
    });
  });

  group('MetadataCleaner Title & Artist Normalization', () {
    test('cleanTitle strips noise brackets, visualizer tags, and feature strings', () {
      expect(MetadataCleaner.cleanTitle('Shape of You (Official Music Video)'), equals('Shape of You'));
      expect(MetadataCleaner.cleanTitle('Blinding Lights [Lyrics]'), equals('Blinding Lights'));
      expect(MetadataCleaner.cleanTitle('Despacito feat. Daddy Yankee'), equals('Despacito'));
      expect(MetadataCleaner.cleanTitle('Plain Track Title'), equals('Plain Track Title'));
    });

    test('cleanArtist and primaryArtist strip topic suffix and split collaborations', () {
      expect(MetadataCleaner.cleanArtist('The Beatles - Topic'), equals('The Beatles'));
      expect(MetadataCleaner.primaryArtist('Dua Lipa, Elton John'), equals('Dua Lipa'));
      expect(MetadataCleaner.primaryArtist('Calvin Harris feat. Rihanna'), equals('Calvin Harris'));
    });
  });

  group('QueueStatus Index Re-pointing & Filtering', () {
    test('filtered maintains current item index when preceding items are removed', () {
      final items = [
        const MediaMetadata(id: '1', title: 'Song 1', artists: [Artist(id: 'a1', name: 'Artist 1')]),
        const MediaMetadata(id: '2', title: 'Song 2', artists: [Artist(id: 'a2', name: 'Artist 2')]),
        const MediaMetadata(id: '3', title: 'Song 3 (Current)', artists: [Artist(id: 'a3', name: 'Artist 3')]),
        const MediaMetadata(id: '4', title: 'Song 4', artists: [Artist(id: 'a4', name: 'Artist 4')]),
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
        const MediaMetadata(id: '1', title: 'Song 1', artists: [Artist(id: 'a1', name: 'Artist 1')]),
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

  group('DownloadProgress & DownloadState Verification', () {
    test('DownloadProgress state and progress values are retained', () {
      const p1 = DownloadProgress(DownloadState.queued, 0.0);
      expect(p1.state, equals(DownloadState.queued));
      expect(p1.progress, equals(0.0));

      const p2 = DownloadProgress(DownloadState.downloading, 0.45);
      expect(p2.state, equals(DownloadState.downloading));
      expect((p2.progress * 100).toInt(), equals(45));

      const p3 = DownloadProgress(DownloadState.completed, 1.0);
      expect(p3.state, equals(DownloadState.completed));
      expect(p3.progress, equals(1.0));
    });
  });

  group('Player Bar Responsive Layout Math', () {
    test('calculates wide column width clamping between 340 and 480 px', () {
      double computeLeftWidth(double screenW, bool isCompact) {
        return isCompact
            ? (screenW * 0.28).clamp(240.0, 320.0)
            : (screenW * 0.26).clamp(340.0, 480.0);
      }

      // Compact viewports (<1080)
      expect(computeLeftWidth(900, true), closeTo(252.0, 0.01));
      expect(computeLeftWidth(800, true), closeTo(240.0, 0.01)); // clamped min
      expect(computeLeftWidth(1200, true), closeTo(320.0, 0.01)); // clamped max

      // Standard desktop viewports (>=1080)
      expect(computeLeftWidth(1920, false), closeTo(480.0, 0.01)); // max clamped (spacious title)
      expect(computeLeftWidth(1440, false), closeTo(374.4, 0.01)); // generous middle width
      expect(computeLeftWidth(1100, false), closeTo(340.0, 0.01)); // clamped min
    });
  });
}

import 'package:echo_music/core/utils.dart';
import 'package:echo_music/data/database.dart';
import 'package:echo_music/innertube/models/yt_item.dart';
import 'package:echo_music/playback/media_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Models & Database Row Serialization', () {
    test('SongRow preserves liked status and timestamps', () {
      final now = DateTime.now();
      final row = SongRow(
        id: 'track_123',
        title: 'Everybody Wants To Rule The World',
        duration: 251,
        thumbnailUrl: 'https://lh3.googleusercontent.com/test',
        albumId: 'album_456',
        albumName: 'Songs from the Big Chair',
        explicit: false,
        date: now,
        liked: true,
        likedDate: now,
        totalPlayTime: 1250,
      );

      final map = row.toMap();
      expect(map['id'], equals('track_123'));
      expect(map['title'], equals('Everybody Wants To Rule The World'));
      expect(map['duration'], equals(251));
      expect(map['liked'], equals(1));
      expect(map['likedDate'], equals(now.millisecondsSinceEpoch));

      final restored = SongRow.fromMap(map);
      expect(restored.id, equals(row.id));
      expect(restored.title, equals(row.title));
      expect(restored.liked, isTrue);
      expect(restored.likedDate?.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('PlaylistRow special IDs are invariant', () {
      expect(PlaylistRow.likedId, equals('LP_LIKED'));
      expect(PlaylistRow.downloadedId, equals('LP_DOWNLOADED'));
    });

    test('MediaMetadata from SongItem preserves artists, album, and duration', () {
      final songItem = SongItem(
        id: 's_999',
        title: 'Stayin Alive',
        artists: [Artist(id: 'a_1', name: 'Bee Gees')],
        album: Album(id: 'alb_1', name: 'Saturday Night Fever'),
        duration: 285,
        thumbnail: 'https://lh3.googleusercontent.com/art',
      );

      final meta = MediaMetadata.fromSongItem(songItem);
      expect(meta.id, equals('s_999'));
      expect(meta.title, equals('Stayin Alive'));
      expect(meta.artists.first.name, equals('Bee Gees'));
      expect(meta.album?.name, equals('Saturday Night Fever'));
      expect(meta.duration, equals(285));
      expect(meta.thumbnailUrl, equals('https://lh3.googleusercontent.com/art'));
    });
  });

  group('Utility Formatting Functions', () {
    test('formatDuration formats seconds into mm:ss and hh:mm:ss', () {
      expect(formatDuration(0), equals('0:00'));
      expect(formatDuration(59), equals('0:59'));
      expect(formatDuration(60), equals('1:00'));
      expect(formatDuration(185), equals('3:05'));
      expect(formatDuration(3665), equals('1:01:05'));
    });

    test('responsiveGridColumns calculates stable column counts for responsive widths', () {
      expect(responsiveGridColumns(300), equals(2));
      expect(responsiveGridColumns(500), equals(2));
      expect(responsiveGridColumns(600), equals(3));
      expect(responsiveGridColumns(750), equals(3));
      expect(responsiveGridColumns(800), equals(4));
      expect(responsiveGridColumns(1000), equals(4));
      expect(responsiveGridColumns(1100), equals(5));
      expect(responsiveGridColumns(1300), equals(5));
      expect(responsiveGridColumns(1400), equals(6));
      expect(responsiveGridColumns(1800), equals(6));
    });
  });
}

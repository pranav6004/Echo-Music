import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../data/database.dart';
import '../innertube/models/yt_item.dart';
import '../innertube/youtube.dart';
import '../playback/media_metadata.dart';

class SpotifyImportItem {
  final String title;
  final String artist;
  final int? durationSec;

  const SpotifyImportItem({
    required this.title,
    required this.artist,
    this.durationSec,
  });
}

class SpotifyPlaylistData {
  final String id;
  final String name;
  final String? coverUrl;
  final List<SpotifyImportItem> tracks;

  const SpotifyPlaylistData({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.tracks,
  });
}

class SpotifyImporter {
  SpotifyImporter._();
  static final instance = SpotifyImporter._();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      },
    ),
  );

  static final _playlistUrlRegex = RegExp(r'playlist[/:]([A-Za-z0-9]+)');
  static final _bareIdRegex = RegExp(r'^[A-Za-z0-9]{16,}$');

  String? parsePlaylistId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final m = _playlistUrlRegex.firstMatch(trimmed);
    if (m != null) return m.group(1);
    if (_bareIdRegex.hasMatch(trimmed)) return trimmed;
    return null;
  }

  Future<SpotifyPlaylistData> fetchPlaylist(String playlistIdOrUrl) async {
    final id = parsePlaylistId(playlistIdOrUrl);
    if (id == null) {
      throw Exception('Invalid Spotify playlist URL or ID');
    }

    final res = await _dio.get<String>(
      'https://open.spotify.com/embed/playlist/$id',
    );
    final html = res.data ?? '';

    final match = RegExp(
      r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (match == null) {
      throw Exception('Could not extract playlist information from Spotify');
    }

    final jsonStr = match.group(1)!;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final entity = data['props']?['pageProps']?['state']?['data']?['entity']
        as Map<String, dynamic>?;

    if (entity == null) {
      throw Exception('Playlist not found or is private');
    }

    final name = (entity['name'] as String?) ?? 'Spotify Playlist';
    final cover = entity['coverArt']?['sources']?[0]?['url'] as String?;
    final rawTracks = entity['trackList'] as List<dynamic>? ?? [];

    final tracks = <SpotifyImportItem>[];
    for (final t in rawTracks) {
      if (t is Map) {
        final title = t['title'] as String? ?? '';
        final subtitle = t['subtitle'] as String? ?? '';
        if (title.isNotEmpty) {
          final dur = t['duration'] as int?;
          tracks.add(
            SpotifyImportItem(
              title: title,
              artist: subtitle,
              durationSec: dur != null ? dur ~/ 1000 : null,
            ),
          );
        }
      }
    }

    return SpotifyPlaylistData(
      id: id,
      name: name,
      coverUrl: cover,
      tracks: tracks,
    );
  }

  Future<int> importToLibrary({
    required SpotifyPlaylistData data,
    required void Function(int current, int total, String trackName) onProgress,
  }) async {
    final db = Database.instance;
    final yt = YouTube.instance;

    // 1. Create Playlist in database
    final playlist = await db.createPlaylist(
      data.name,
      thumbnailUrl: data.coverUrl,
    );

    final matchedTracks = <MediaMetadata>[];
    final total = data.tracks.length;

    for (var i = 0; i < total; i++) {
      final track = data.tracks[i];
      onProgress(i + 1, total, '${track.title} - ${track.artist}');

      try {
        final query = '${track.title} ${track.artist}'.trim();
        final searchRes = await yt.search(query, filter: SearchFilter.song);
        final songs = searchRes.items.whereType<SongItem>().toList();

        if (songs.isNotEmpty) {
          matchedTracks.add(MediaMetadata.fromSongItem(songs.first));
        }
      } catch (_) {}

      // Slight delay to be polite to YouTube API
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (matchedTracks.isNotEmpty) {
      await db.addToPlaylist(playlist.id, matchedTracks);
    }

    return matchedTracks.length;
  }
}

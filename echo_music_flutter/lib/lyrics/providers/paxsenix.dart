import 'package:dio/dio.dart';

import '../lyrics_utils.dart';

/// Port of `paxsenixlyrics/Paxsenix.kt`: Apple Music lyrics via paxsenix API.
class PaxsenixProvider {
  PaxsenixProvider._();
  static final instance = PaxsenixProvider._();
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://lyrics.paxsenix.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Resona/1.0',
      },
    ),
  );

  Future<String?> getLyrics(
    String title,
    String artist,
    int durationSec, {
    String? album,
  }) async {
    try {
      final cleanTitle = MetadataCleaner.cleanTitle(title);
      final query = '$cleanTitle $artist'.trim();
      final res = await _dio.get<dynamic>(
        '/apple-music/search',
        queryParameters: {'q': query},
      );
      final data = res.data;
      if (data is! List || data.isEmpty) return null;

      final first = data.first;
      if (first is! Map) return null;
      final songId = first['id']?.toString();
      if (songId == null || songId.isEmpty) return null;

      final lyricRes = await _dio.get<dynamic>(
        '/apple-music/lyrics',
        queryParameters: {'id': songId},
      );
      final lyricData = lyricRes.data;
      if (lyricData is Map) {
        final ttml = lyricData['ttml'] as String?;
        if (ttml != null && ttml.isNotEmpty) return ttml;
        final lrc = lyricData['lrc'] as String?;
        if (lrc != null && lrc.isNotEmpty) return lrc;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

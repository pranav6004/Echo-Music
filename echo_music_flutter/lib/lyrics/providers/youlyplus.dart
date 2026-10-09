import 'package:dio/dio.dart';

import '../lyrics_utils.dart';

/// Port of `youlyplus/YouLyPlus.kt`: LyricsPlus multi-mirror lyrics engine.
class YouLyPlusProvider {
  YouLyPlusProvider._();
  static final instance = YouLyPlusProvider._();

  static const _servers = [
    'https://lyricsplus.prjktla.my.id',
    'https://lyricsplus.atomix.one',
    'https://lyricsplus.binimum.org',
    'https://lyricsplus.prjktla.workers.dev',
    'https://lyricsplus-seven.vercel.app',
    'https://lyrics-plus-backend.vercel.app',
  ];

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'EchoMusic/1.0',
      },
    ),
  );

  Future<String?> getLyrics(
    String title,
    String artist,
    int durationSec, {
    String? album,
  }) async {
    final cleanTitle = LyricsUtils.cleanTitle(title);
    for (final host in _servers) {
      try {
        final res = await _dio.get<dynamic>(
          '$host/v2/lyrics/get',
          queryParameters: {
            'title': cleanTitle,
            'artist': artist,
            if (durationSec > 0) 'duration': durationSec,
          },
        );
        final data = res.data;
        if (data is Map) {
          final lrc = data['lyrics'] ?? data['lrc'] ?? data['syncedLyrics'];
          if (lrc is String && lrc.trim().isNotEmpty) {
            return lrc.trim();
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

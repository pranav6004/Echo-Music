import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CanvasArtwork {
  final String? videoUrl;
  final String? animatedUrl;
  final String provider;

  const CanvasArtwork({
    this.videoUrl,
    this.animatedUrl,
    required this.provider,
  });

  String? get preferredUrl => animatedUrl ?? videoUrl;
}

class CanvasService extends ChangeNotifier {
  CanvasService._();
  static final instance = CanvasService._();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final Map<String, CanvasArtwork?> _cache = {};

  String? _currentUrl;
  String? get currentUrl => _currentUrl;

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|feat\..*|ft\..*'), '')
        .trim();
  }

  Future<CanvasArtwork?> getCanvas({
    required String title,
    required String artist,
    String? album,
  }) async {
    final normTitle = _normalize(title);
    final normArtist = _normalize(artist);
    final key = '$normTitle|$normArtist';

    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // 1. Try ArchiveTune Canvas
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://artwork-archivetune.koiiverse.cloud/',
        queryParameters: {
          's': normTitle,
          'a': normArtist,
          if (album != null && album.isNotEmpty) 'al': album,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data!;
        final anim = data['animated'] as String?;
        final video = data['videoUrl'] as String?;
        if ((anim != null && anim.isNotEmpty) || (video != null && video.isNotEmpty)) {
          final art = CanvasArtwork(
            animatedUrl: anim,
            videoUrl: video,
            provider: 'ArchiveTune',
          );
          _cache[key] = art;
          return art;
        }
      }
    } catch (_) {}

    // 2. Try Tidal Canvas API
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.tidal.com/v1/search/tracks',
        queryParameters: {
          'query': '$normTitle $normArtist',
          'limit': 5,
          'countryCode': 'US',
        },
        options: Options(headers: {'x-tidal-token': 'vNVdglQOjFJJGG2U'}),
      );
      if (res.statusCode == 200 && res.data != null) {
        final items = res.data!['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          for (final item in items) {
            final mediaMetadata = item['mediaMetadata'] as Map<String, dynamic>?;
            final tags = mediaMetadata?['tags'] as List<dynamic>?;
            if (tags != null && tags.contains('CANVAS')) {
              final trackId = item['id'];
              final url = 'https://resources.tidal.com/videos/$trackId/1280x720.mp4';
              final art = CanvasArtwork(videoUrl: url, provider: 'Tidal');
              _cache[key] = art;
              return art;
            }
          }
        }
      }
    } catch (_) {}

    _cache[key] = null;
    return null;
  }

  Future<void> updateCurrentTrack({
    required String title,
    required String artist,
    String? album,
  }) async {
    final art = await getCanvas(title: title, artist: artist, album: album);
    _currentUrl = art?.preferredUrl;
    notifyListeners();
  }
}

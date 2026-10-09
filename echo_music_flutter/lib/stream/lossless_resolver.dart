import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'stream_resolver.dart';

/// Resolves true lossless audio streams (FLAC 1411 kbps 16-bit/44.1kHz or Hi-Res).
///
/// Uses open cross-platform song matching (Songlink / Odesli) to locate ISRC
/// and matches against open Hi-Fi endpoints. If an endpoint is unavailable or
/// times out, returns null to allow seamless fallback to YouTube Opus.
class LosslessResolver {
  LosslessResolver._();
  static final instance = LosslessResolver._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
    ),
  );

  final _cache = <String, ResolvedStream>{};

  Future<ResolvedStream?> resolve({
    required String videoId,
    required String title,
    String? artist,
  }) async {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached;
    }

    try {
      final stream = await _findLosslessStream(
        videoId: videoId,
        title: title,
        artist: artist,
      ).timeout(const Duration(seconds: 4));

      if (stream != null) {
        _cache[videoId] = stream;
        debugPrint('[lossless] $videoId ($title) resolved via ${stream.clientName} (FLAC)');
        return stream;
      }
    } catch (e) {
      debugPrint('[lossless] $videoId resolve attempt skipped: $e');
    }
    return null;
  }

  Future<ResolvedStream?> _findLosslessStream({
    required String videoId,
    required String title,
    String? artist,
  }) async {
    // 1. Query Songlink API to resolve ISRC / platform IDs
    final songlinkUrl = 'https://api.song.link/v1-alpha.1/links?url=https://music.youtube.com/watch?v=$videoId';
    final res = await _dio.get<Map<String, dynamic>>(songlinkUrl);
    if (res.statusCode != 200 || res.data == null) return null;

    final data = res.data!;
    final links = data['linksByPlatform'] as Map<String, dynamic>? ?? {};

    // Check Tidal or Deezer matches
    final tidalLink = links['tidal'] as Map<String, dynamic>?;
    final deezerLink = links['deezer'] as Map<String, dynamic>?;

    String? tidalId;
    if (tidalLink != null && tidalLink['url'] is String) {
      final uri = Uri.tryParse(tidalLink['url'] as String);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        tidalId = uri.pathSegments.last;
      }
    }

    String? deezerId;
    if (deezerLink != null && deezerLink['url'] is String) {
      final uri = Uri.tryParse(deezerLink['url'] as String);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        deezerId = uri.pathSegments.last;
      }
    }

    // 2. Query open Hi-Fi endpoints if Tidal or Deezer ID is available
    if (tidalId != null && tidalId.isNotEmpty) {
      final tidalStream = await _probeTidalStream(videoId, tidalId);
      if (tidalStream != null) return tidalStream;
    }

    if (deezerId != null && deezerId.isNotEmpty) {
      final deezerStream = await _probeDeezerStream(videoId, deezerId);
      if (deezerStream != null) return deezerStream;
    }

    return null;
  }

  Future<ResolvedStream?> _probeTidalStream(String videoId, String tidalId) async {
    // Probe open Tidal Hi-Fi mirror
    final mirrors = [
      'https://api.monochrome.network/v1/track/$tidalId',
      'https://triton.squid.wtf/track/$tidalId',
    ];

    for (final mirror in mirrors) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(mirror);
        if (res.statusCode == 200 && res.data != null) {
          final streamUrl = res.data!['streamUrl'] ?? res.data!['url'];
          if (streamUrl is String && streamUrl.isNotEmpty) {
            return ResolvedStream(
              videoId: videoId,
              url: streamUrl,
              mimeType: 'audio/flac',
              bitrate: 1411200,
              clientName: 'Tidal Hi-Fi (Lossless)',
              headers: const {'User-Agent': 'EchoMusic/1.0'},
              expiresAt: DateTime.now().add(const Duration(hours: 3)),
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<ResolvedStream?> _probeDeezerStream(String videoId, String deezerId) async {
    try {
      final endpoint = 'https://api.deezer.com/track/$deezerId';
      final res = await _dio.get<Map<String, dynamic>>(endpoint);
      if (res.statusCode == 200 && res.data != null) {
        // If Deezer preview/stream is available
        final preview = res.data!['preview'];
        if (preview is String && preview.isNotEmpty) {
          // Deezer mp3 preview is not FLAC, so don't claim lossless
          return null;
        }
      }
    } catch (_) {}
    return null;
  }

  void clearCache() => _cache.clear();
}

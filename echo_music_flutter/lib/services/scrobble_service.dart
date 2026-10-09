import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../data/settings.dart';
import '../playback/media_metadata.dart';

/// Scrobbling service supporting Last.fm and ListenBrainz.
class ScrobbleService {
  ScrobbleService._();
  static final instance = ScrobbleService._();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  String? _currentTrackId;
  int _startTimestampSec = 0;
  bool _nowPlayingSent = false;
  bool _scrobbled = false;

  void onTrackStarted(MediaMetadata metadata) {
    _currentTrackId = metadata.id;
    _startTimestampSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _nowPlayingSent = false;
    _scrobbled = false;

    _sendNowPlaying(metadata);
  }

  void onPositionUpdate(MediaMetadata metadata, Duration position, Duration total) {
    if (_currentTrackId != metadata.id) {
      onTrackStarted(metadata);
      return;
    }

    if (!_nowPlayingSent && position.inSeconds >= 5) {
      _sendNowPlaying(metadata);
    }

    if (_scrobbled) return;

    final durationSec = metadata.duration > 0 ? metadata.duration : total.inSeconds;
    if (durationSec < 30) return; // Last.fm minimum track length rule

    final elapsedSec = position.inSeconds;
    final scrobblePointSec = (durationSec / 2).clamp(30, 240); // 50% or max 4 min

    if (elapsedSec >= scrobblePointSec) {
      _scrobbled = true;
      _sendScrobble(metadata, _startTimestampSec);
    }
  }

  Future<void> _sendNowPlaying(MediaMetadata metadata) async {
    _nowPlayingSent = true;
    final s = Settings.instance;

    if (s.enableLastFm && s.lastFmSessionKey.isNotEmpty && s.lastFmApiKey.isNotEmpty) {
      _lastFmNowPlaying(metadata, s.lastFmApiKey, s.lastFmApiSecret, s.lastFmSessionKey);
    }

    if (s.enableListenBrainz && s.listenBrainzToken.isNotEmpty) {
      _listenBrainzNowPlaying(metadata, s.listenBrainzToken);
    }
  }

  Future<void> _sendScrobble(MediaMetadata metadata, int timestampSec) async {
    final s = Settings.instance;

    if (s.enableLastFm && s.lastFmSessionKey.isNotEmpty && s.lastFmApiKey.isNotEmpty) {
      _lastFmScrobble(metadata, timestampSec, s.lastFmApiKey, s.lastFmApiSecret, s.lastFmSessionKey);
    }

    if (s.enableListenBrainz && s.listenBrainzToken.isNotEmpty) {
      _listenBrainzScrobble(metadata, timestampSec, s.listenBrainzToken);
    }
  }

  // --- Last.fm API ---

  Future<void> _lastFmNowPlaying(
    MediaMetadata m,
    String apiKey,
    String apiSecret,
    String sk,
  ) async {
    try {
      final params = <String, String>{
        'method': 'track.updateNowPlaying',
        'artist': m.artistsText,
        'track': m.title,
        if (m.album?.name != null && m.album!.name.isNotEmpty) 'album': m.album!.name,
        'api_key': apiKey,
        'sk': sk,
      };

      params['api_sig'] = _generateLastFmSignature(params, apiSecret);
      params['format'] = 'json';

      await _dio.post<dynamic>(
        'https://ws.audioscrobbler.com/2.0/',
        data: FormData.fromMap(params),
      );
    } catch (_) {}
  }

  Future<void> _lastFmScrobble(
    MediaMetadata m,
    int timestampSec,
    String apiKey,
    String apiSecret,
    String sk,
  ) async {
    try {
      final params = <String, String>{
        'method': 'track.scrobble',
        'artist': m.artistsText,
        'track': m.title,
        'timestamp': '$timestampSec',
        if (m.album?.name != null && m.album!.name.isNotEmpty) 'album': m.album!.name,
        'api_key': apiKey,
        'sk': sk,
      };

      params['api_sig'] = _generateLastFmSignature(params, apiSecret);
      params['format'] = 'json';

      await _dio.post<dynamic>(
        'https://ws.audioscrobbler.com/2.0/',
        data: FormData.fromMap(params),
      );
    } catch (_) {}
  }

  String _generateLastFmSignature(Map<String, String> params, String secret) {
    final sortedKeys = params.keys.where((k) => k != 'format' && k != 'api_sig').toList()..sort();
    var sig = '';
    for (final k in sortedKeys) {
      sig += '$k${params[k]}';
    }
    sig += secret;
    return md5.convert(utf8.encode(sig)).toString();
  }

  // --- ListenBrainz API ---

  Future<void> _listenBrainzNowPlaying(MediaMetadata m, String token) async {
    try {
      await _dio.post<dynamic>(
        'https://api.listenbrainz.org/1/submit-listens',
        options: Options(
          headers: {
            'Authorization': 'Token $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'listen_type': 'playing_now',
          'payload': [
            {
              'track_metadata': {
                'artist_name': m.artistsText,
                'track_name': m.title,
                if (m.album?.name != null) 'release_name': m.album!.name,
              },
            },
          ],
        },
      );
    } catch (_) {}
  }

  Future<void> _listenBrainzScrobble(
    MediaMetadata m,
    int timestampSec,
    String token,
  ) async {
    try {
      await _dio.post<dynamic>(
        'https://api.listenbrainz.org/1/submit-listens',
        options: Options(
          headers: {
            'Authorization': 'Token $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'listen_type': 'single',
          'payload': [
            {
              'listened_at': timestampSec,
              'track_metadata': {
                'artist_name': m.artistsText,
                'track_name': m.title,
                if (m.album?.name != null) 'release_name': m.album!.name,
              },
            },
          ],
        },
      );
    } catch (_) {}
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../playback/media_metadata.dart';

class RoomUser {
  final String userId;
  final String username;
  final bool isHost;

  const RoomUser({
    required this.userId,
    required this.username,
    required this.isHost,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? 'User').toString(),
      isHost: json['is_host'] ?? json['isHost'] ?? false,
    );
  }
}

class SyncedTrack {
  final String id;
  final String title;
  final String artist;
  final String? thumbnail;
  final int duration;

  const SyncedTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnail,
    required this.duration,
  });

  factory SyncedTrack.fromJson(Map<String, dynamic> json) {
    // Cloudflare audit: sanitize track ID to prevent path traversal or injection
    final rawId = (json['id'] ?? '').toString();
    final sanitizedId = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

    return SyncedTrack(
      id: sanitizedId,
      title: (json['title'] ?? '').toString(),
      artist: (json['artist'] ?? '').toString(),
      thumbnail: json['thumbnail'] as String?,
      duration: (json['duration'] ?? 0) is int
          ? (json['duration'] ?? 0) as int
          : int.tryParse(json['duration'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    if (thumbnail != null) 'thumbnail': thumbnail,
    'duration': duration,
  };
}

class ListenTogetherService extends ChangeNotifier {
  ListenTogetherService._();
  static final instance = ListenTogetherService._();

  static const defaultServer = 'wss://metroserverx.meowery.eu/ws';
  static const fallbackServer = 'wss://devilmi-vivi-music-listen-together.hf.space';
  static const int _maxMessageBytes = 65536; // 64 KB message size limit

  WebSocket? _ws;
  Timer? _pingTimer;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _roomCode;
  String? get roomCode => _roomCode;

  String? _userId;
  String? get userId => _userId;

  String _username = 'Resona Listener';
  String get username => _username;

  bool _isHost = false;
  bool get isHost => _isHost;

  final List<RoomUser> _members = [];
  List<RoomUser> get members => List.unmodifiable(_members);

  SyncedTrack? _currentTrack;
  SyncedTrack? get currentTrack => _currentTrack;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _positionMs = 0;
  int get positionMs => _positionMs;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  // External playback controller callback for client syncing
  Future<void> Function(SyncedTrack track, bool play, int positionMs)? onSyncRequest;

  void setUsername(String name) {
    _username = name.trim().isEmpty ? 'Resona Listener' : name.trim();
    notifyListeners();
  }

  Future<void> createRoom({String? serverUrl}) async {
    await _connect(serverUrl ?? defaultServer);
    if (!_isConnected || _ws == null) return;

    _statusMessage = 'Creating party room...';
    notifyListeners();

    _send('create_room', {'username': _username});
  }

  Future<void> joinRoom(String code, {String? serverUrl}) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    await _connect(serverUrl ?? defaultServer);
    if (!_isConnected || _ws == null) return;

    _statusMessage = 'Joining room $cleanCode...';
    notifyListeners();

    _send('join_room', {
      'room_code': cleanCode,
      'username': _username,
    });
  }

  Future<void> leaveRoom() async {
    if (_ws != null) {
      _send('leave_room', null);
    }
    _disconnect();
    _roomCode = null;
    _userId = null;
    _isHost = false;
    _members.clear();
    _currentTrack = null;
    _statusMessage = 'Disconnected';
    notifyListeners();
  }

  Future<void> _connect(String url, {bool allowFallback = true}) async {
    if (_isConnected) return;

    // Cloudflare security: enforce WSS encryption unless connecting to localhost
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'wss' && uri.host != '127.0.0.1' && uri.host != 'localhost')) {
      _statusMessage = 'Security warning: Only encrypted wss:// connections allowed';
      notifyListeners();
      return;
    }

    _isConnecting = true;
    _statusMessage = 'Connecting to server...';
    notifyListeners();

    try {
      _ws = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      _isConnected = true;
      _isConnecting = false;
      _statusMessage = 'Connected to sync server';
      notifyListeners();

      _startPing();
      _ws!.listen(
        _onMessage,
        onError: (err) {
          _statusMessage = 'Connection error: $err';
          _disconnect();
          notifyListeners();
        },
        onDone: () {
          _statusMessage = 'Disconnected from server';
          _disconnect();
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _statusMessage = 'Failed to connect: $e';
      notifyListeners();

      // Retry once on fallback server if initial default failed
      if (allowFallback && url == defaultServer) {
        await _connect(fallbackServer, allowFallback: false);
      }
    }
  }

  void _disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _isConnected = false;
    _isConnecting = false;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send('ping', null);
    });
  }

  void _send(String type, Map<String, dynamic>? payload) {
    if (_ws == null) return;
    try {
      final msg = jsonEncode({
        'type': type,
        if (payload != null) 'payload': payload,
      });
      _ws!.add(msg);
    } catch (e) {
      debugPrint('[ListenTogether] Send failed: $e');
    }
  }

  static String? _str(Map<String, dynamic>? map, String k1, [String? k2]) {
    if (map == null) return null;
    final val = map[k1] ?? (k2 != null ? map[k2] : null);
    return val?.toString();
  }

  void _onMessage(dynamic raw) {
    try {
      // Cloudflare audit: guard against oversized frames causing memory exhaustion
      if (raw is List<int> && raw.length > _maxMessageBytes) return;
      if (raw is String && raw.length > _maxMessageBytes) return;

      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final map = jsonDecode(text) as Map<String, dynamic>;
      final type = map['type'] as String?;
      final payload = map['payload'] as Map<String, dynamic>?;

      if (type == null) return;

      switch (type) {
        case 'room_created':
          _roomCode = _str(payload, 'room_code', 'roomCode');
          _userId = _str(payload, 'user_id', 'userId');
          _isHost = true;
          _members.clear();
          _members.add(RoomUser(userId: _userId ?? '', username: _username, isHost: true));
          _statusMessage = 'Room $_roomCode created';
          notifyListeners();
          break;

        case 'join_request':
          final guestId = _str(payload, 'user_id', 'userId');
          if (guestId != null && _isHost && _members.length < 50) {
            _send('approve_join', {'user_id': guestId});
          }
          break;

        case 'join_approved':
          _roomCode = _str(payload, 'room_code', 'roomCode');
          _userId = _str(payload, 'user_id', 'userId');
          _isHost = false;
          _members.clear();
          final state = payload?['state'] as Map<String, dynamic>?;
          if (state != null) {
            final users = state['users'] as List<dynamic>?;
            if (users != null) {
              for (final u in users) {
                if (u is Map<String, dynamic>) {
                  _members.add(RoomUser.fromJson(u));
                }
              }
            }
          }
          if (_members.isEmpty) {
            _members.add(RoomUser(userId: _userId ?? '', username: _username, isHost: false));
          }
          _statusMessage = 'Joined room $_roomCode';
          notifyListeners();
          break;

        case 'user_joined':
          final uid = _str(payload, 'user_id', 'userId') ?? '';
          final uname = payload?['username']?.toString() ?? 'Guest';
          if (!_members.any((m) => m.userId == uid)) {
            _members.add(RoomUser(userId: uid, username: uname, isHost: false));
            notifyListeners();
          }
          break;

        case 'user_left':
          final uid = _str(payload, 'user_id', 'userId') ?? '';
          _members.removeWhere((m) => m.userId == uid);
          notifyListeners();
          break;

        case 'playback_action':
        case 'sync_playback':
          if (!_isHost && payload != null) {
            final action = payload['action']?.toString();
            final pos = (payload['position'] ?? 0) is int
                ? payload['position'] as int
                : int.tryParse(payload['position'].toString()) ?? 0;
            final tInfo = payload['track_info'] as Map<String, dynamic>?;

            if (tInfo != null) {
              _currentTrack = SyncedTrack.fromJson(tInfo);
            }
            _positionMs = pos.clamp(0, 86400000); // Max 24 hours
            _isPlaying = action == 'play';

            if (_currentTrack != null && onSyncRequest != null && _currentTrack!.id.isNotEmpty) {
              onSyncRequest!(_currentTrack!, _isPlaying, _positionMs);
            }
            notifyListeners();
          }
          break;

        case 'error':
          _statusMessage = payload?['message']?.toString() ?? 'Server error';
          notifyListeners();
          break;
      }
    } catch (e) {
      debugPrint('[ListenTogether] Parse message error: $e');
    }
  }

  // Host broadcasts local state changes
  void broadcastPlayback({
    required MediaMetadata metadata,
    required bool isPlaying,
    required Duration position,
  }) {
    if (!_isHost || !_isConnected || _roomCode == null) return;

    final track = SyncedTrack(
      id: metadata.id,
      title: metadata.title,
      artist: metadata.artistsText,
      thumbnail: metadata.thumbnailUrl,
      duration: metadata.duration,
    );
    _currentTrack = track;
    _isPlaying = isPlaying;
    _positionMs = position.inMilliseconds;

    _send('playback_action', {
      'action': isPlaying ? 'play' : 'pause',
      'track_id': metadata.id,
      'position': position.inMilliseconds,
      'track_info': track.toJson(),
    });
  }
}

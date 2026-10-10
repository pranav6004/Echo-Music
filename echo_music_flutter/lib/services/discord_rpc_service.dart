import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import '../data/settings.dart';
import '../playback/media_metadata.dart';
import 'log_service.dart';

/// Discord Rich Presence client communicating via local IPC.
/// On Windows: uses native Named Pipes (\\.\pipe\discord-ipc-0).
/// On Linux/macOS: uses Unix Domain Sockets (/tmp/discord-ipc-0 or XDG_RUNTIME_DIR).
class DiscordRpcService {
  DiscordRpcService._();
  static final instance = DiscordRpcService._();

  static const _clientId = '1518210534070292541'; // Resona official client ID
  static const _maxPipes = 10;

  bool _connected = false;
  int _windowsHandle = -1;
  Socket? _unixSocket;
  Timer? _reconnectTimer;

  MediaMetadata? _lastMeta;
  Duration _lastPosition = Duration.zero;
  bool _lastIsPlaying = false;

  bool get isConnected => _connected;

  void init() {
    if (Settings.instance.enableDiscordRpc) {
      connect();
    }
    Settings.instance.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (Settings.instance.enableDiscordRpc) {
      if (!_connected) connect();
    } else {
      if (_connected) disconnect();
    }
  }

  Future<void> connect() async {
    if (_connected) return;
    try {
      if (Platform.isWindows) {
        _connectWindows();
      } else if (Platform.isLinux || Platform.isMacOS) {
        await _connectUnix();
      }
    } catch (e) {
      LogService.instance.log('discord', 'Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect([Duration delay = const Duration(seconds: 5)]) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (Settings.instance.enableDiscordRpc && !_connected) {
        connect();
      }
    });
  }

  void _connectWindows() {
    final k32 = _Win32.k32;
    if (k32 == null) return;

    for (var i = 0; i < _maxPipes; i++) {
      final pipeName = '\\\\.\\pipe\\discord-ipc-$i';
      final h = _Win32.openPipe(pipeName);
      if (h != -1) {
        _windowsHandle = h;
        _connected = true;
        _reconnectTimer?.cancel();
        LogService.instance.log('discord', 'Connected via $pipeName');
        _sendHandshake();
        _pushCurrentPresence();
        return;
      }
    }

    _connected = false;
    _scheduleReconnect(const Duration(seconds: 5));
  }

  Future<void> _connectUnix() async {
    final xdg = Platform.environment['XDG_RUNTIME_DIR'];
    final tmp = Platform.environment['TMPDIR'] ?? '/tmp';

    for (var i = 0; i < _maxPipes; i++) {
      final candidates = [
        if (xdg != null) '$xdg/discord-ipc-$i',
        '$tmp/discord-ipc-$i',
        '/tmp/discord-ipc-$i',
      ];

      for (final p in candidates) {
        try {
          final s = await Socket.connect(
            InternetAddress(p, type: InternetAddressType.unix),
            0,
            timeout: const Duration(seconds: 2),
          );
          _unixSocket = s;
          _connected = true;
          _reconnectTimer?.cancel();
          LogService.instance.log('discord', 'Connected via $p');
          _sendHandshake();
          _pushCurrentPresence();
          return;
        } catch (_) {}
      }
    }

    _connected = false;
    _scheduleReconnect(const Duration(seconds: 5));
  }

  void _sendHandshake() {
    final payload = jsonEncode({'v': 1, 'client_id': _clientId});
    _sendPacket(0, payload); // Opcode 0 = HANDSHAKE
  }

  void _pushCurrentPresence() {
    if (!_connected || _lastMeta == null || !_lastIsPlaying) return;
    updatePresence(
      title: _lastMeta!.title,
      artist: _lastMeta!.artistsText,
      album: _lastMeta!.album?.name,
      artworkUrl: _lastMeta!.thumbnailUrl,
      durationSec: _lastMeta!.duration,
      elapsedSec: _lastPosition.inSeconds,
      isPlaying: _lastIsPlaying,
    );
  }

  void updatePresence({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
    int? durationSec,
    int? elapsedSec,
    bool isPlaying = true,
  }) {
    if (!_connected || !Settings.instance.enableDiscordRpc) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final start = elapsedSec != null ? now - (elapsedSec * 1000) : now;
    final end = (durationSec != null && durationSec > 0)
        ? start + (durationSec * 1000)
        : null;

    final activity = {
      'details': title,
      'state': artist,
      if (isPlaying && end != null)
        'timestamps': {
          'start': start,
          'end': end,
        }
      else if (isPlaying)
        'timestamps': {
          'start': start,
        },
      'assets': {
        'large_image': (artworkUrl != null && artworkUrl.isNotEmpty)
            ? artworkUrl
            : 'icon',
        'large_text': (album != null && album.isNotEmpty) ? album : title,
        'small_text': isPlaying ? 'Playing' : 'Paused',
      },
    };

    final payload = jsonEncode({
      'cmd': 'SET_ACTIVITY',
      'args': {
        'pid': pid,
        'activity': activity,
      },
      'nonce': '${DateTime.now().microsecondsSinceEpoch}',
    });

    _sendPacket(1, payload); // Opcode 1 = FRAME
    LogService.instance.log('discord', 'Presence sent: $title - $artist');
  }

  void updateFromMedia({
    required MediaMetadata metadata,
    required Duration position,
    required bool isPlaying,
  }) {
    _lastMeta = metadata;
    _lastPosition = position;
    _lastIsPlaying = isPlaying;

    if (!Settings.instance.enableDiscordRpc) return;

    if (!_connected) {
      connect();
      return;
    }

    if (!isPlaying) {
      clearPresence();
      return;
    }

    updatePresence(
      title: metadata.title,
      artist: metadata.artistsText,
      album: metadata.album?.name,
      artworkUrl: metadata.thumbnailUrl,
      durationSec: metadata.duration,
      elapsedSec: position.inSeconds,
      isPlaying: isPlaying,
    );
  }

  void clearPresence() {
    if (!_connected) return;
    final payload = jsonEncode({
      'cmd': 'SET_ACTIVITY',
      'args': {
        'pid': pid,
        'activity': null,
      },
      'nonce': '${DateTime.now().microsecondsSinceEpoch}',
    });
    _sendPacket(1, payload);
  }

  void disconnect() {
    clearPresence();
    _connected = false;
    if (_windowsHandle != -1) {
      _Win32.closePipe(_windowsHandle);
      _windowsHandle = -1;
    }
    _unixSocket?.destroy();
    _unixSocket = null;
    _reconnectTimer?.cancel();
  }

  void _sendPacket(int opcode, String jsonStr) {
    try {
      final utf8Bytes = utf8.encode(jsonStr);
      final header = ByteData(8)
        ..setUint32(0, opcode, Endian.little)
        ..setUint32(4, utf8Bytes.length, Endian.little);
      final packet = Uint8List(8 + utf8Bytes.length)
        ..setRange(0, 8, header.buffer.asUint8List())
        ..setRange(8, 8 + utf8Bytes.length, utf8Bytes);

      if (Platform.isWindows && _windowsHandle != -1) {
        final success = _Win32.writePipe(_windowsHandle, packet);
        if (!success) {
          LogService.instance.log('discord', 'writePipe failed, reconnecting...');
          _connected = false;
          _windowsHandle = -1;
          _scheduleReconnect();
        }
      } else if (_unixSocket != null) {
        _unixSocket!.add(packet);
      }
    } catch (e) {
      LogService.instance.log('discord', 'Packet error: $e');
      _connected = false;
      _scheduleReconnect();
    }
  }
}

/// Lightweight Win32 FFI wrapper for Windows Named Pipe I/O.
class _Win32 {
  static final k32 = Platform.isWindows
      ? ffi.DynamicLibrary.open('kernel32.dll')
      : null;

  static final _createFile = k32?.lookupFunction<
    ffi.IntPtr Function(
      ffi.Pointer<ffi.Uint16>,
      ffi.Uint32,
      ffi.Uint32,
      ffi.Pointer<ffi.Void>,
      ffi.Uint32,
      ffi.Uint32,
      ffi.IntPtr,
    ),
    int Function(
      ffi.Pointer<ffi.Uint16>,
      int,
      int,
      ffi.Pointer<ffi.Void>,
      int,
      int,
      int,
    )
  >('CreateFileW');

  static final _writeFile = k32?.lookupFunction<
    ffi.Int32 Function(
      ffi.IntPtr,
      ffi.Pointer<ffi.Uint8>,
      ffi.Uint32,
      ffi.Pointer<ffi.Uint32>,
      ffi.Pointer<ffi.Void>,
    ),
    int Function(
      int,
      ffi.Pointer<ffi.Uint8>,
      int,
      ffi.Pointer<ffi.Uint32>,
      ffi.Pointer<ffi.Void>,
    )
  >('WriteFile');

  static final _closeHandle = k32?.lookupFunction<
    ffi.Int32 Function(ffi.IntPtr),
    int Function(int)
  >('CloseHandle');

  static final _virtualAlloc = k32?.lookupFunction<
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<ffi.Void>,
      ffi.Size,
      ffi.Uint32,
      ffi.Uint32,
    ),
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>, int, int, int)
  >('VirtualAlloc');

  static ffi.Pointer<ffi.Uint16>? _nameBuf;
  static ffi.Pointer<ffi.Uint8>? _ioBuf;
  static ffi.Pointer<ffi.Uint32>? _writtenBuf;

  static void _ensureBuffers() {
    if (_ioBuf != null) return;
    final va = _virtualAlloc;
    if (va == null) return;

    _nameBuf = va(ffi.Pointer.fromAddress(0), 1024, 0x1000 | 0x2000, 0x04).cast<ffi.Uint16>();
    _ioBuf = va(ffi.Pointer.fromAddress(0), 65536, 0x1000 | 0x2000, 0x04).cast<ffi.Uint8>();
    _writtenBuf = va(ffi.Pointer.fromAddress(0), 64, 0x1000 | 0x2000, 0x04).cast<ffi.Uint32>();
  }

  static int openPipe(String name) {
    final cf = _createFile;
    if (cf == null) return -1;
    _ensureBuffers();
    final namePtr = _nameBuf;
    if (namePtr == null || namePtr.address == 0) return -1;

    final units = name.codeUnits;
    for (var i = 0; i < units.length; i++) {
      namePtr[i] = units[i];
    }
    namePtr[units.length] = 0;

    const genericReadWrite = 0x80000000 | 0x40000000;
    const openExisting = 3;
    const fileAttributeNormal = 0x80;

    return cf(
      namePtr,
      genericReadWrite,
      0,
      ffi.Pointer.fromAddress(0),
      openExisting,
      fileAttributeNormal,
      0,
    );
  }

  static bool writePipe(int handle, Uint8List data) {
    final wf = _writeFile;
    if (wf == null || handle == -1) return false;
    _ensureBuffers();
    final ioBuf = _ioBuf;
    final writtenBuf = _writtenBuf;
    if (ioBuf == null || writtenBuf == null || ioBuf.address == 0 || writtenBuf.address == 0) {
      return false;
    }

    if (data.length > 65536) return false;

    for (var i = 0; i < data.length; i++) {
      ioBuf[i] = data[i];
    }

    final result = wf(
      handle,
      ioBuf,
      data.length,
      writtenBuf,
      ffi.Pointer.fromAddress(0),
    );

    return result != 0;
  }

  static void closePipe(int handle) {
    _closeHandle?.call(handle);
  }
}

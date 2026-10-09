import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import '../data/settings.dart';
import '../playback/media_metadata.dart';

/// Discord Rich Presence client communicating via local IPC.
/// On Windows: uses native Named Pipes (\\.\pipe\discord-ipc-0).
/// On Linux/macOS: uses Unix Domain Sockets (/tmp/discord-ipc-0 or XDG_RUNTIME_DIR).
class DiscordRpcService {
  DiscordRpcService._();
  static final instance = DiscordRpcService._();

  static const _clientId = '1518210534070292541'; // Echo Music official client ID
  static const _maxPipes = 10;

  bool _connected = false;
  int _windowsHandle = -1;
  Socket? _unixSocket;
  Timer? _reconnectTimer;

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
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 30), () {
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
        _sendHandshake();
        return;
      }
    }
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
          _sendHandshake();
          return;
        } catch (_) {}
      }
    }
  }

  void _sendHandshake() {
    final payload = jsonEncode({'v': 1, 'client_id': _clientId});
    _sendPacket(0, payload); // Opcode 0 = HANDSHAKE
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
        'small_image': isPlaying ? 'play' : 'pause',
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
  }

  void updateFromMedia({
    required MediaMetadata metadata,
    required Duration position,
    required bool isPlaying,
  }) {
    if (!Settings.instance.enableDiscordRpc) return;

    if (!_connected) {
      connect();
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
          _connected = false;
          _windowsHandle = -1;
          _scheduleReconnect();
        }
      } else if (_unixSocket != null) {
        _unixSocket!.add(packet);
      }
    } catch (_) {
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

  static final _virtualFree = k32?.lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Size, ffi.Uint32),
    int Function(ffi.Pointer<ffi.Void>, int, int)
  >('VirtualFree');

  static int openPipe(String name) {
    final cf = _createFile;
    final va = _virtualAlloc;
    final vf = _virtualFree;
    if (cf == null || va == null || vf == null) return -1;

    final units = name.codeUnits;
    final size = (units.length + 1) * 2;
    final ptr = va(ffi.Pointer.fromAddress(0), size, 0x1000 | 0x2000, 0x04)
        .cast<ffi.Uint16>();
    if (ptr.address == 0) return -1;

    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;

    const genericReadWrite = 0x80000000 | 0x40000000;
    const openExisting = 3;
    const fileAttributeNormal = 0x80;

    final handle = cf(
      ptr,
      genericReadWrite,
      0,
      ffi.Pointer.fromAddress(0),
      openExisting,
      fileAttributeNormal,
      0,
    );

    vf(ptr.cast<ffi.Void>(), 0, 0x8000);
    return handle;
  }

  static bool writePipe(int handle, Uint8List data) {
    final wf = _writeFile;
    final va = _virtualAlloc;
    final vf = _virtualFree;
    if (wf == null || va == null || vf == null) return false;

    final ptr = va(
      ffi.Pointer.fromAddress(0),
      data.length + 8,
      0x1000 | 0x2000,
      0x04,
    ).cast<ffi.Uint8>();
    if (ptr.address == 0) return false;

    for (var i = 0; i < data.length; i++) {
      ptr[i] = data[i];
    }

    final bytesWrittenPtr = ptr.elementAt(data.length).cast<ffi.Uint32>();
    final result = wf(
      handle,
      ptr,
      data.length,
      bytesWrittenPtr,
      ffi.Pointer.fromAddress(0),
    );

    vf(ptr.cast<ffi.Void>(), 0, 0x8000);
    return result != 0;
  }

  static void closePipe(int handle) {
    _closeHandle?.call(handle);
  }
}

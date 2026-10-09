import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry({
    required this.time,
    required this.tag,
    required this.message,
  });

  String get formattedTime {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() => '[$formattedTime][$tag] $message';
}

/// In-memory ring buffer holding the most recent 500 app log entries.
/// Accessible via Settings -> Developer Options -> System Logs.
class LogService extends ChangeNotifier {
  LogService._();
  static final instance = LogService._();

  static const int maxLogs = 500;
  final Queue<LogEntry> _logs = Queue<LogEntry>();

  List<LogEntry> get logs => _logs.toList();

  void init() {
    // Intercept debugPrint to automatically populate logs
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        _captureRawMessage(message);
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
    log('app', 'LogService initialized');
  }

  void _captureRawMessage(String message) {
    String tag = 'sys';
    String content = message;
    if (message.startsWith('[') && message.contains(']')) {
      final end = message.indexOf(']');
      tag = message.substring(1, end);
      content = message.substring(end + 1).trim();
    }
    _addEntry(LogEntry(time: DateTime.now(), tag: tag, message: content));
  }

  void log(String tag, String message) {
    _addEntry(LogEntry(time: DateTime.now(), tag: tag, message: message));
    debugPrint('[$tag] $message');
  }

  void _addEntry(LogEntry entry) {
    if (_logs.length >= maxLogs) {
      _logs.removeFirst();
    }
    _logs.addLast(entry);
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> copyAll() async {
    final text = _logs.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
  }
}

import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error, http }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.details,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toFormattedString() {
    final sb = StringBuffer();
    sb.writeln('[$formattedTime] [${level.name.toUpperCase()}] [$tag] $message');
    if (details != null && details!.isNotEmpty) {
      sb.writeln('Details: $details');
    }
    return sb.toString();
  }
}

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void addLog({
    required LogLevel level,
    required String tag,
    required String message,
    String? details,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      details: details,
    );

    _logs.insert(0, entry); // newest first

    // Limit in-memory logs to 200 entries
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }

    notifyListeners();

    if (kDebugMode) {
      debugPrint('[${entry.level.name.toUpperCase()}] [${entry.tag}] ${entry.message}');
      if (details != null && details.isNotEmpty) {
        debugPrint(details);
      }
    }
  }

  void info(String tag, String message, [String? details]) =>
      addLog(level: LogLevel.info, tag: tag, message: message, details: details);

  void warning(String tag, String message, [String? details]) =>
      addLog(level: LogLevel.warning, tag: tag, message: message, details: details);

  void error(String tag, String message, [String? details]) =>
      addLog(level: LogLevel.error, tag: tag, message: message, details: details);

  void http(String tag, String message, [String? details]) =>
      addLog(level: LogLevel.http, tag: tag, message: message, details: details);

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String getAllLogsAsText() {
    return _logs.reversed.map((e) => e.toFormattedString()).join('\n---\n');
  }
}

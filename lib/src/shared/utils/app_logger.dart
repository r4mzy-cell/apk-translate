import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static bool _initialized = false;
  static File? _logFile;
  static const int _maxLogFiles = 7;
  static const int _maxLogSizeBytes = 5 * 1024 * 1024; // 5MB

  static Future<void> init() async {
  if (_initialized) return;
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _cleanOldLogs(logDir);
    _logFile = File(p.join(logDir.path, 'app_${DateTime.now().toIso8601String().split('T').first}.log'));
    await _logFile!.create();
    _initialized = true;
    info('AppLogger initialized');
  }

  static void _cleanOldLogs(Directory logDir) {
    final files = logDir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (var i = _maxLogFiles; i < files.length; i++) {
      files[i].deleteSync();
    }
  }

  static void _write(String level, String message, [Object? error, StackTrace? stack]) {
    if (!_initialized) return;
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer('$timestamp [$level] $message');
    if (error != null) buffer.write('\n  Error: $error');
    if (stack != null) buffer.write('\n  Stack: $stack');
    _logFile?.writeAsStringSync('${buffer.toString()}\n', mode: FileMode.append);
    // Also print to console in debug
    if (level == 'ERROR' || level == 'WARN') {
      print(buffer.toString());
    }
  }

  static void debug(String message) => _write('DEBUG', message);
  static void info(String message) => _write('INFO', message);
  static void warn(String message, [Object? error, StackTrace? stack]) => _write('WARN', message, error, stack);
  static void error(String message, [Object? error, StackTrace? stack]) => _write('ERROR', message, error, stack);

  static Future<String?> getLogs({int lines = 1000}) async {
    if (!_initialized || _logFile == null) return null;
    final content = await _logFile!.readAsString();
    return content.split('\n').reversed.take(lines).reversed.join('\n');
  }

  static Future<void> clearLogs() async {
    await _logFile?.delete();
    await init();
  }
}
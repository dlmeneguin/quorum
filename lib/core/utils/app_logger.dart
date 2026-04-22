import 'dart:async';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static final _controller =
      StreamController<LogEntry>.broadcast();

  static Stream<LogEntry> get stream => _controller.stream;
  static final List<LogEntry> history = [];

  static void init() {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      // Ainda imprime no console nativo
      // ignore: avoid_print
      print(message);

      final entry = LogEntry(
        message: message,
        timestamp: DateTime.now(),
      );
      history.add(entry);
      // Mantém no máximo 500 linhas em memória
      if (history.length > 500) history.removeAt(0);
      _controller.add(entry);
    };
  }

  static void dispose() {
    _controller.close();
  }
}

class LogEntry {
  final String message;
  final DateTime timestamp;

  LogEntry({required this.message, required this.timestamp});

  LogCategory get category {
    if (message.contains('[Sync]')) return LogCategory.sync;
    if (message.contains('[Auth]')) return LogCategory.auth;
    if (message.contains('[Drive]')) return LogCategory.drive;
    if (message.contains('[Pluggy]') ||
        message.contains('pluggy') ||
        message.contains('Pluggy')) return LogCategory.pluggy;
    if (message.toLowerCase().contains('erro') ||
        message.toLowerCase().contains('error') ||
        message.toLowerCase().contains('exception')) {
      return LogCategory.error;
    }
    return LogCategory.general;
  }
}

enum LogCategory { sync, auth, drive, pluggy, error, general }
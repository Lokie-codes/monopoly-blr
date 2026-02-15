import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// #16: Lightweight logger replacing raw print() statements.
/// Uses dart:developer log in debug mode, no-ops in release.
class AppLogger {
  static const String _defaultName = 'MonopolyBLR';

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(message, name: tag ?? _defaultName, level: 800);
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('⚠️ $message', name: tag ?? _defaultName, level: 900);
    }
  }

  static void error(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      developer.log('❌ $message', name: tag ?? _defaultName, level: 1000, error: error);
    }
  }
}

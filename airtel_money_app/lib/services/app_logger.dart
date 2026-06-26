import 'dart:developer' as developer;

/// Logs terminal — uniquement en cas d'erreur (debug / profile).
class AppLogger {
  AppLogger._();

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

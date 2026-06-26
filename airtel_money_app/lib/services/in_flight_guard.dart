/// Évite les appels API dupliqués simultanés (coalescing).
class InFlightGuard {
  InFlightGuard._();

  static final InFlightGuard instance = InFlightGuard._();
  final _pending = <String, Future<dynamic>>{};

  Future<T> run<T>(String key, Future<T> Function() action) {
    final existing = _pending[key];
    if (existing != null) return existing as Future<T>;

    final future = action().whenComplete(() => _pending.remove(key));
    _pending[key] = future;
    return future;
  }

  void cancelAll() => _pending.clear();
}

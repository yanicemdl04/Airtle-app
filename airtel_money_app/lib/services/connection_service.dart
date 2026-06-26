import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../config/performance_config.dart';
import 'api_client.dart';
import 'app_logger.dart';

/// Résout l'URL backend la plus rapide via GET /health.
/// Notifie l'UI quand l'état réseau change.
class ConnectionService extends ChangeNotifier {
  ConnectionService._();

  static final ConnectionService instance = ConnectionService._();

  String? _activeUrl;
  int? _latencyMs;
  String? _lastError;
  DateTime? _lastResolvedAt;
  bool _resolving = false;
  Future<bool>? _resolveFuture;

  String? get activeUrl => _activeUrl;
  int? get latencyMs => _latencyMs;
  String? get lastError => _lastError;
  bool get isConnected => _activeUrl != null;
  bool get isResolving => _resolving;

  /// Teste une URL et retourne la latence en ms, ou null si échec.
  Future<int?> probe(
    String baseUrl, {
    Duration timeout = PerformanceConfig.healthProbeTimeout,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/health',
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      _lastError = _friendlyError(e, baseUrl);
    } catch (e, st) {
      _lastError = e.toString();
      AppLogger.error('Connection', _lastError!, error: e, stackTrace: st);
    }
    return null;
  }

  /// Lance les sondes en parallèle et retient la première URL qui répond.
  Future<bool> resolveBestUrl({
    String? manualUrl,
    bool force = false,
  }) {
    if (!force &&
        isConnected &&
        _lastResolvedAt != null &&
        DateTime.now().difference(_lastResolvedAt!) <
            PerformanceConfig.connectionCacheTtl) {
      return Future.value(true);
    }

    final inFlight = _resolveFuture;
    if (inFlight != null && !force) return inFlight;

    _resolveFuture = _resolveBestUrlInternal(manualUrl: manualUrl);
    return _resolveFuture!.whenComplete(() => _resolveFuture = null);
  }

  Future<bool> _resolveBestUrlInternal({String? manualUrl}) async {
    _resolving = true;
    notifyListeners();

    await ApiConfig.init();
    final saved = await ApiConfig.loadSavedUrl();
    final candidates = ApiConfig.candidateUrls(savedUrl: manualUrl ?? saved);

    _lastError = null;
    if (manualUrl == null) {
      _activeUrl = null;
      _latencyMs = null;
    }

    final platformDefault = ApiConfig.baseUrl;
    final ordered = [
      if (manualUrl != null) ApiConfig.normalize(manualUrl),
      platformDefault,
      ...candidates.where((u) => u != platformDefault),
    ].toSet().toList();

    final best = await _raceProbes(ordered);

    _resolving = false;

    if (best == null) {
      _lastError ??=
          'Serveur inaccessible. Vérifiez que le backend tourne (npm run start:dev).\n'
          '${ApiConfig.platformHint}';
      notifyListeners();
      return false;
    }

    _applyResolved(best.$1, best.$2);
    await ApiConfig.saveUrl(best.$1);
    _lastResolvedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  /// Retourne dès que la première sonde réussit ; annule les autres.
  Future<(String url, int ms)?> _raceProbes(List<String> urls) async {
    if (urls.isEmpty) return null;

    final completer = Completer<(String, int)?>();
    final cancelTokens = <CancelToken>[];
    var pending = urls.length;

    void onDone((String, int)? result) {
      pending--;
      if (result != null && !completer.isCompleted) {
        completer.complete(result);
      } else if (pending == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final url in urls) {
      final token = CancelToken();
      cancelTokens.add(token);
      probe(url, cancelToken: token).then((ms) {
        onDone(ms != null ? (url, ms) : null);
      }).catchError((Object _) {
        onDone(null);
      });
    }

    try {
      return await completer.future.timeout(
        PerformanceConfig.connectionResolveTimeout,
        onTimeout: () => null,
      );
    } finally {
      for (final token in cancelTokens) {
        if (!token.isCancelled) token.cancel('URL trouvée ou échec global');
      }
    }
  }

  /// Teste une URL saisie manuellement (écran de config).
  Future<bool> testManualUrl(String url) async {
    final normalized = ApiConfig.normalize(url);
    final ms = await probe(normalized);
    if (ms == null) {
      notifyListeners();
      return false;
    }
    _applyResolved(normalized, ms);
    await ApiConfig.saveUrl(normalized);
    _lastResolvedAt = DateTime.now();
    _lastError = null;
    notifyListeners();
    return true;
  }

  void markDisconnected([String? reason]) {
    _activeUrl = null;
    _latencyMs = null;
    _lastResolvedAt = null;
    if (reason != null) _lastError = reason;
    notifyListeners();
  }

  void updateAfterManualTest(String url, int ms) {
    _applyResolved(url, ms);
    _lastResolvedAt = DateTime.now();
    notifyListeners();
  }

  void _applyResolved(String url, int ms) {
    _activeUrl = url;
    _latencyMs = ms;
    _lastError = null;
    ApiClient.instance.updateBaseUrl(url);
  }

  String _friendlyError(DioException e, String url) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Délai dépassé pour $url';
      case DioExceptionType.connectionError:
        return 'Connexion refusée sur $url — backend éteint ou mauvaise IP';
      default:
        return 'Erreur réseau ($url) : ${e.message}';
    }
  }
}

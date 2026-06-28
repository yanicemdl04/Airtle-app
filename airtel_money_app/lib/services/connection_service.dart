import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../config/performance_config.dart';
import 'api_client.dart';
import 'app_logger.dart';

/// Résout l'URL backend via GET /health et synchronise [ApiClient].
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

  /// À appeler avant tout appel API (login, restore session, etc.).
  Future<bool> ensureConnected({bool force = false}) async {
    if (force && _activeUrl != null) {
      final ms = await probe(_activeUrl!);
      if (ms != null) {
        _latencyMs = ms;
        _lastResolvedAt = DateTime.now();
        _lastError = null;
        return true;
      }
    }
    return resolveBestUrl(force: force);
  }

  Future<int?> probe(
    String baseUrl, {
    Duration timeout = PerformanceConfig.healthProbeTimeout,
    CancelToken? cancelToken,
  }) async {
    if (baseUrl.isEmpty) return null;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: _probeHeaders(baseUrl),
      ),
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/health',
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      if (response.statusCode == 200 && _isHealthyResponse(response.data)) {
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

  bool _isHealthyResponse(Map<String, dynamic>? data) {
    if (data == null) return false;

    final nested = data['data'];
    final body = nested is Map<String, dynamic> ? nested : data;

    // Nouveau backend : GET /api/health
    final status = body['status'] as String?;
    final database = body['database'] as String?;
    if (status == 'ok' && database == 'connected') return true;

    // Ancien format (rétrocompatibilité)
    return body['service'] == 'airtel-money-api';
  }

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
    final saved = manualUrl ?? await ApiConfig.loadSavedUrl();
    final hadSaved = saved != null && saved.isNotEmpty;
    final candidates = await ApiConfig.candidateUrls(savedUrl: saved);

    _lastError = null;

    final ordered = _uniqueOrdered([
      if (manualUrl != null) ApiConfig.normalize(manualUrl),
      if (saved != null && saved.isNotEmpty) ApiConfig.normalize(saved),
      if (ApiConfig.hasBuildTimeUrl) ApiConfig.baseUrl,
      if (ApiConfig.baseUrl.isNotEmpty) ApiConfig.baseUrl,
      ...candidates,
    ]);

    final best = await _raceProbes(ordered);

    _resolving = false;

    if (best == null) {
      _activeUrl = null;
      _latencyMs = null;
      _lastError ??= _buildUnreachableMessage();
      notifyListeners();
      return false;
    }

    _applyResolved(best.$1, best.$2);

    // Ne pas écraser une URL manuelle sauvegardée par une auto-détection.
    if (manualUrl != null || !hadSaved) {
      await ApiConfig.saveUrl(best.$1);
    }

    _lastResolvedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  List<String> _uniqueOrdered(List<String> urls) {
    final seen = <String>{};
    final result = <String>[];
    for (final url in urls) {
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      result.add(url);
    }
    return result;
  }

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
        if (!token.isCancelled) token.cancel('Résolution terminée');
      }
    }
  }

  Future<bool> testManualUrl(String url) async {
    final trimmed = url.trim();
    if (ApiConfig.looksLikePlaceholder(trimmed)) {
      _lastError =
          'URL d’exemple détectée — copiez l’URL réelle affichée par ngrok '
          '(Forwarding https://…).ngrok-free.app → http://localhost:…)';
      notifyListeners();
      return false;
    }

    final normalized = ApiConfig.normalize(trimmed);
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

  void _applyResolved(String url, int ms) {
    _activeUrl = url;
    _latencyMs = ms;
    _lastError = null;
    ApiConfig.setResolvedUrl(url);
    ApiClient.instance.updateBaseUrl(url);
  }

  String _buildUnreachableMessage() {
    return 'Serveur inaccessible.\n'
        '1. Backend : cd backend && docker compose up -d && npm run start:dev\n'
        '2. ${ApiConfig.platformHint}';
  }

  Map<String, String> _probeHeaders(String baseUrl) {
    if (!baseUrl.contains('ngrok')) return const {};
    return const {'ngrok-skip-browser-warning': 'true'};
  }

  String _friendlyError(DioException e, String url) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Délai dépassé pour $url';
      case DioExceptionType.connectionError:
        return 'Connexion refusée sur $url — backend éteint, mauvaise IP ou pare-feu';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) {
          return 'Endpoint introuvable (404) sur $url/health.\n\n'
              'Vérifications :\n'
              '1. ngrok actif → copiez l’URL « Forwarding » (pas un exemple)\n'
              '2. Backend démarré → npm run start:dev\n'
              '3. Bon port → ngrok http 3000 (ou 3001 selon .env)\n'
              '4. Test navigateur → $url/health';
        }
        if (code == 502 || code == 503) {
          return 'ngrok joignable mais backend arrêté ($code).\n'
              'Lancez : docker compose up -d postgres && npm run start:dev';
        }
        return 'Erreur HTTP $code sur $url';
      default:
        return 'Erreur réseau ($url) : ${e.message}';
    }
  }
}

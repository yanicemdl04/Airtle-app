import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/device_utils.dart';

/// Configuration de l'URL backend NestJS (persistée + override build).
class ApiConfig {
  ApiConfig._();

  static const _prefKey = 'api_base_url';

  /// Port par défaut (3001 — le 3000 est souvent occupé sous Windows).
  static const defaultApiPort = 3001;
  static const legacyApiPort = 3000;
  static const apiPorts = [3001, 3000, 3002, 3003, 3004];

  /// Build : flutter build apk --dart-define=API_BASE_URL=http://192.168.1.15:3001/api
  static const String _dartDefineUrl = String.fromEnvironment('API_BASE_URL');

  static String _resolvedUrl = '';
  static bool _initialized = false;
  static bool? _isEmulator;

  static String get baseUrl {
    if (_resolvedUrl.isNotEmpty) return _resolvedUrl;
    return _syncPlatformDefault();
  }

  static bool get isInitialized => _initialized;
  static bool get hasBuildTimeUrl => _dartDefineUrl.isNotEmpty;

  static const deviceId = 'flutter-airtel-money-001';

  static String urlForHost(String host, [int port = defaultApiPort]) =>
      'http://$host:$port/api';

  /// URLs testées par [ConnectionService] via GET /health.
  static Future<List<String>> candidateUrls({String? savedUrl}) async {
    final isEmulator = await _ensureEmulatorFlag();
    final candidates = <String>[];

    void add(String? url) {
      if (url == null || url.isEmpty) return;
      candidates.add(normalize(url));
    }

    add(_dartDefineUrl);
    add(savedUrl);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (isEmulator) {
        for (final port in apiPorts) {
          add(urlForHost('10.0.2.2', port));
        }
      }
      // Téléphone physique : pas de 10.0.2.2 / 127.0.0.1 (inutiles hors émulateur).
    } else {
      for (final port in apiPorts) {
        add(urlForHost('127.0.0.1', port));
        add(urlForHost('localhost', port));
      }
    }

    return candidates.toSet().toList();
  }

  static String _syncPlatformDefault() {
    if (kIsWeb) return urlForHost('localhost');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return urlForHost('10.0.2.2');
      case TargetPlatform.iOS:
        return urlForHost('127.0.0.1');
      default:
        return urlForHost('127.0.0.1');
    }
  }

  static Future<String> _platformDefaultAsync() async {
    if (kIsWeb) return urlForHost('localhost');

    if (defaultTargetPlatform == TargetPlatform.android) {
      final isEmulator = await _ensureEmulatorFlag();
      if (isEmulator) return urlForHost('10.0.2.2');
      // Téléphone physique : config obligatoire (build ou écran login).
      return '';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final isEmulator = await _ensureEmulatorFlag();
      return urlForHost(isEmulator ? '127.0.0.1' : '127.0.0.1');
    }

    return urlForHost('127.0.0.1');
  }

  static Future<bool> _ensureEmulatorFlag() async {
    _isEmulator ??= await isRunningOnEmulator();
    return _isEmulator!;
  }

  static Future<bool> get isPhysicalAndroid async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return !(await _ensureEmulatorFlag());
  }

  static String normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.endsWith('/api')) {
      // http://192.168.1.15:3001 → …/api
      if (RegExp(r':\d+$').hasMatch(u)) {
        u = '$u/api';
      }
      // https://xxxx.ngrok-free.app → …/api
      else if (u.contains('ngrok')) {
        u = '$u/api';
      }
    }
    return u;
  }

  /// Détecte les URLs d'exemple (documentation) jamais valides en production.
  static bool looksLikePlaceholder(String url) {
    final lower = url.toLowerCase();
    return lower.contains('xxxx') ||
        lower.contains('a1b2c3d4') ||
        lower.contains('abc123') ||
        lower.contains('<ip_du_pc>') ||
        lower.contains('votre-url') ||
        lower.contains('mon-url');
  }

  static Future<String?> loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  static Future<void> saveUrl(String url) async {
    final normalized = normalize(url);
    if (normalized.isEmpty) return;
    _resolvedUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
  }

  static void setResolvedUrl(String url) {
    _resolvedUrl = normalize(url);
    _initialized = true;
  }

  static Future<void> init() async {
    if (_initialized && _resolvedUrl.isNotEmpty) return;

    if (_dartDefineUrl.isNotEmpty) {
      _resolvedUrl = normalize(_dartDefineUrl);
      _initialized = true;
      return;
    }

    final saved = await loadSavedUrl();
    if (saved != null && saved.isNotEmpty) {
      _resolvedUrl = normalize(saved);
      _initialized = true;
      return;
    }

    _resolvedUrl = normalize(await _platformDefaultAsync());
    _initialized = true;
  }

  static String get platformHint {
    if (hasBuildTimeUrl) {
      return 'URL fixée au build : $_dartDefineUrl';
    }
    if (kIsWeb) return 'Web → localhost:$defaultApiPort/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Émulateur : http://10.0.2.2:$defaultApiPort/api · '
            'Wi-Fi : http://<IP_PC>:$defaultApiPort/api · '
            'ngrok : https://<ID>.ngrok-free.app/api';
      case TargetPlatform.iOS:
        return 'Simulateur : 127.0.0.1:$defaultApiPort · iPhone : IP du PC';
      default:
        return 'PC : http://127.0.0.1:$defaultApiPort/api';
    }
  }

  static String get apkBuildHint =>
      'flutter build apk --dart-define=API_BASE_URL=https://<ID>.ngrok-free.app/api';
}

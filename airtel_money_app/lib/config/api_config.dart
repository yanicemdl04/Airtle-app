import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'package:flutter/material.dart' show TargetPlatform;

import 'package:shared_preferences/shared_preferences.dart';



/// Configuration de l'API backend NestJS avec URL persistante et override build.

class ApiConfig {

  ApiConfig._();



  static const _prefKey = 'api_base_url';



  /// Port par défaut (3001 — le 3000 est souvent bloqué/occupé sous Windows).

  static const defaultApiPort = 3001;

  static const legacyApiPort = 3000;

  static const apiPorts = [3001, 3000, 3002, 3003, 3004];



  /// Override au build : flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3001/api

  static const String _dartDefineUrl = String.fromEnvironment('API_BASE_URL');



  static String _resolvedUrl = '';

  static bool _initialized = false;



  static String get baseUrl {

    if (_resolvedUrl.isNotEmpty) return _resolvedUrl;

    return _platformDefault();

  }



  static bool get isInitialized => _initialized;



  static const deviceId = 'flutter-airtel-money-001';



  static String urlForHost(String host, [int port = defaultApiPort]) =>

      'http://$host:$port/api';



  /// Candidats testés automatiquement (health check rapide).

  static List<String> candidateUrls({String? savedUrl}) {

    final candidates = <String>[];



    if (_dartDefineUrl.isNotEmpty) candidates.add(normalize(_dartDefineUrl));

    if (savedUrl != null && savedUrl.isNotEmpty) {

      candidates.add(normalize(savedUrl));

    }



    candidates.add(normalize(_platformDefault()));



    for (final port in apiPorts) {

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {

        candidates.add(urlForHost('10.0.2.2', port));

        candidates.add(urlForHost('127.0.0.1', port));

      }

      if (!kIsWeb &&

          (defaultTargetPlatform == TargetPlatform.windows ||

              defaultTargetPlatform == TargetPlatform.linux ||

              defaultTargetPlatform == TargetPlatform.macOS)) {

        candidates.add(urlForHost('127.0.0.1', port));

        candidates.add(urlForHost('localhost', port));

      }

      if (kIsWeb) {

        candidates.add(urlForHost('localhost', port));

      }

    }



    return candidates.toSet().toList();

  }



  static String _platformDefault() {

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



  static String normalize(String url) {

    var u = url.trim();

    if (u.endsWith('/')) u = u.substring(0, u.length - 1);

    if (!u.endsWith('/api') && RegExp(r':\d+$').hasMatch(u)) {

      u = '$u/api';

    }

    return u;

  }



  static Future<String?> loadSavedUrl() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_prefKey);

  }



  static Future<void> saveUrl(String url) async {

    final normalized = normalize(url);

    _resolvedUrl = normalized;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_prefKey, normalized);

  }



  static Future<void> setResolvedUrl(String url) async {

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

    } else {

      _resolvedUrl = normalize(_platformDefault());

    }

    _initialized = true;

  }



  static String get platformHint {

    if (kIsWeb) return 'Web → localhost:$defaultApiPort';

    switch (defaultTargetPlatform) {

      case TargetPlatform.android:

        return 'Émulateur : 10.0.2.2:$defaultApiPort · Téléphone : IP du PC (ex. 192.168.x.x:$defaultApiPort)';

      case TargetPlatform.iOS:

        return 'Simulateur : 127.0.0.1:$defaultApiPort · iPhone : IP du PC';

      default:

        return 'PC : 127.0.0.1:$defaultApiPort (ports $defaultApiPort ou $legacyApiPort testés auto)';

    }

  }

}



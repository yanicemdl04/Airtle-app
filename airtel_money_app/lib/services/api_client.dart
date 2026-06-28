import 'package:dio/dio.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../config/api_config.dart';

import '../config/performance_config.dart';

import 'api_exception.dart';

import 'app_logger.dart';

import 'connection_service.dart';

import 'in_flight_guard.dart';



/// Client HTTP singleton — retry, reconnexion auto et déduplication.

class ApiClient {

  ApiClient._() {

    _dio = Dio(

      BaseOptions(

        baseUrl: ApiConfig.baseUrl,

        connectTimeout: PerformanceConfig.connectTimeout,

        receiveTimeout: PerformanceConfig.receiveTimeout,

        headers: {

          'Content-Type': 'application/json',

          'Connection': 'keep-alive',

        },

      ),

    );



    _dio.interceptors.add(

      InterceptorsWrapper(

        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          if (options.uri.host.contains('ngrok')) {
            options.headers['ngrok-skip-browser-warning'] = 'true';
          }
          handler.next(options);
        },

        onError: (error, handler) async {

          if (error.response?.statusCode == 401 &&

              !_isAuthRoute(error.requestOptions.path) &&

              _refreshToken != null) {

            try {

              await _rotateRefreshToken();

              error.requestOptions.headers['Authorization'] =

                  'Bearer $_accessToken';

              final retry = await _dio.fetch(error.requestOptions);

              return handler.resolve(retry);

            } catch (e, st) {

              AppLogger.error(

                'ApiClient',

                'Échec rotation refresh token',

                error: e,

                stackTrace: st,

              );

              await clearTokens();

            }

          }



          if (_isNetworkError(error) &&

              error.requestOptions.extra['url_recovered'] != true) {

            final recovered = await _recoverConnection();

            if (recovered) {

              error.requestOptions.extra['url_recovered'] = true;

              error.requestOptions.baseUrl = _dio.options.baseUrl;

              try {

                final retry = await _dio.fetch(error.requestOptions);

                return handler.resolve(retry);

              } on DioException catch (retryError) {

                return handler.next(retryError);

              }

            }

          }



          handler.next(error);

        },

      ),

    );

  }



  static final ApiClient instance = ApiClient._();



  late Dio _dio;

  String? _accessToken;

  String? _refreshToken;



  bool get isAuthenticated => _accessToken != null;

  String get baseUrl => _dio.options.baseUrl;



  void updateBaseUrl(String url) {

    _dio.options.baseUrl = url;

  }



  bool _isAuthRoute(String path) =>

      path.contains('/auth/login') ||

      path.contains('/auth/register') ||

      path.contains('/auth/refresh');



  Future<void> init() async {

    await ApiConfig.init();

    final active = ConnectionService.instance.activeUrl;

    final url = (active != null && active.isNotEmpty)

        ? active

        : ApiConfig.baseUrl;

    if (url.isNotEmpty) {

      updateBaseUrl(url);

    }

    final prefs = await SharedPreferences.getInstance();

    _accessToken = prefs.getString('access_token');

    _refreshToken = prefs.getString('refresh_token');

  }



  Future<void> setTokens({

    required String accessToken,

    required String refreshToken,

  }) async {

    _accessToken = accessToken;

    _refreshToken = refreshToken;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);

    await prefs.setString('refresh_token', refreshToken);

  }



  Future<void> clearTokens() async {

    _accessToken = null;

    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');

    await prefs.remove('refresh_token');

  }



  Future<void> _rotateRefreshToken() async {

    final response = await _dio.post(

      '/auth/refresh',

      data: {'refreshToken': _refreshToken},

    );

    final data = unwrapData(response.data);

    await setTokens(

      accessToken: data['access_token'] as String,

      refreshToken: data['refresh_token'] as String,

    );

  }



  Future<bool> _recoverConnection() async {

    AppLogger.error('ApiClient', 'Tentative reconnexion au backend…');

    ConnectionService.instance.markDisconnected();

    return ConnectionService.instance.resolveBestUrl(force: true);

  }



  Future<Map<String, dynamic>> get(String path) {

    return InFlightGuard.instance.run('GET:$path', () => _getWithRetry(path));

  }



  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) {

    return InFlightGuard.instance.run(

      'POST:$path:${data.hashCode}',

      () => _postWithRetry(path, data: data),

    );

  }



  /// POST auth direct (login/refresh) — timeout court, sans retry.
  Future<Map<String, dynamic>> postAuth(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: PerformanceConfig.loginTimeout,
        ),
      );
      return unwrapData(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }



  Future<List<Map<String, dynamic>>> getList(String path) {

    return InFlightGuard.instance.run(

      'GET_LIST:$path',

      () => _getListWithRetry(path),

    );

  }



  Future<Map<String, dynamic>> _getWithRetry(String path) async {

    return _withRetry(() async {

      final response = await _dio.get(path);

      return unwrapData(response.data);

    });

  }



  Future<List<Map<String, dynamic>>> _getListWithRetry(String path) async {

    return _withRetry(() async {

      final response = await _dio.get(path);

      return unwrapList(response.data);

    });

  }



  Future<Map<String, dynamic>> _postWithRetry(

    String path, {

    Map<String, dynamic>? data,

  }) async {

    return _withRetry(() async {

      final response = await _dio.post(path, data: data);

      return unwrapData(response.data);

    });

  }



  Future<T> _withRetry<T>(Future<T> Function() action) async {

    var attempt = 0;

    while (true) {

      try {

        return await action();

      } on DioException catch (e) {

        if (!_isRetryable(e) || attempt >= PerformanceConfig.maxRetries) {

          throw _toApiException(e);

        }

        attempt++;

        if (_isNetworkError(e)) {

          await _recoverConnection();

        }

        await Future<void>.delayed(

          PerformanceConfig.retryBaseDelay * attempt,

        );

      }

    }

  }



  bool _isNetworkError(DioException e) {

    return e.type == DioExceptionType.connectionTimeout ||

        e.type == DioExceptionType.receiveTimeout ||

        e.type == DioExceptionType.sendTimeout ||

        e.type == DioExceptionType.connectionError;

  }



  ApiException _toApiException(DioException e) {

    final ApiException ex;

    if (_isNetworkError(e)) {

      ex = ApiException(

        e.type == DioExceptionType.connectionError

            ? 'Impossible de joindre le serveur (${_dio.options.baseUrl}). '

                '${ApiConfig.platformHint}'

            : 'Le serveur met trop de temps à répondre (${_dio.options.baseUrl}). '

                'Vérifiez que le backend est démarré.',

        statusCode: e.response?.statusCode,

        isNetworkError: true,

      );

    } else {

      ex = ApiException(

        extractErrorMessage(e.response?.data),

        statusCode: e.response?.statusCode,

      );

    }

    _logDioError(e, message: ex.message);

    return ex;

  }



  void _logDioError(DioException e, {String? message}) {

    final method = e.requestOptions.method;

    final path = e.requestOptions.uri;

    AppLogger.error(

      'ApiClient',

      '${message ?? e.message} · $method $path · ${e.type.name}'

      '${e.response?.statusCode != null ? ' · HTTP ${e.response!.statusCode}' : ''}',

      error: e,

    );

  }



  bool _isRetryable(DioException e) {

    if (_isNetworkError(e)) return true;

    final code = e.response?.statusCode;

    return code == 502 || code == 503 || code == 504;

  }

}



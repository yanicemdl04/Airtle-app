import 'dart:async';

import '../config/api_config.dart';
import '../utils/phone_utils.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'app_logger.dart';
import 'connection_service.dart';
import 'wallet_store.dart';

/// Service d'authentification — point unique pour login / logout / session.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _initialized = false;

  bool get isAuthenticated => ApiClient.instance.isAuthenticated;

  Future<void> init() async {
    if (_initialized) return;
    await ApiClient.instance.init();
    _initialized = true;
  }

  /// Connexion : POST /auth/login → stockage JWT → sync profil en arrière-plan.
  Future<void> login(String phone, String pin) async {
    await init();

    if (!ConnectionService.instance.isConnected) {
      final connected =
          await ConnectionService.instance.ensureConnected(force: true);
      if (!connected) {
        throw ApiException(
          ConnectionService.instance.lastError ??
              'Serveur inaccessible. Configurez l\'URL du backend.',
          isNetworkError: true,
        );
      }
    }

    final normalizedPhone = normalizePhone(phone);
    final cleanPin = pin.trim();

    if (normalizedPhone.length < 10) {
      throw ApiException('Numéro de téléphone invalide');
    }
    if (cleanPin.length < 4 || cleanPin.length > 6) {
      throw ApiException('PIN à 4-6 chiffres requis');
    }

    try {
      final data = await ApiClient.instance.postAuth('/auth/login', data: {
        'phone': normalizedPhone,
        'pin': cleanPin,
        'deviceId': ApiConfig.deviceId,
      });

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      if (accessToken == null || refreshToken == null) {
        throw ApiException('Réponse login invalide (tokens manquants)');
      }

      await ApiClient.instance.setTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // Ne pas bloquer la navigation — chargement wallet/QR sur l'écran d'accueil.
      unawaited(WalletStore.instance.syncAfterLogin());
    } catch (e, st) {
      AppLogger.error('AuthService', 'Échec login', error: e, stackTrace: st);
      if (e is ApiException) rethrow;
      throw ApiException('Connexion impossible');
    }
  }

  /// Restaure la session si des tokens valides existent.
  Future<bool> restoreSession() async {
    await init();
    if (!isAuthenticated) return false;

    if (!await ConnectionService.instance.ensureConnected()) {
      return false;
    }

    await WalletStore.instance.hydrateFromDisk();

    if (WalletStore.instance.ownerId.isNotEmpty) {
      unawaited(
        WalletStore.instance.refreshAll(force: true).catchError((_) => null),
      );
      return true;
    }

    try {
      await WalletStore.instance.refreshAll(force: true);
      return WalletStore.instance.ownerId.isNotEmpty;
    } catch (e, st) {
      AppLogger.error(
        'AuthService',
        'Session invalide — déconnexion',
        error: e,
        stackTrace: st,
      );
      await logout();
      return false;
    }
  }

  /// Déconnexion locale (tokens + cache utilisateur).
  Future<void> logout() async {
    await WalletStore.instance.clearUserData();
    await ApiClient.instance.clearTokens();
  }
}

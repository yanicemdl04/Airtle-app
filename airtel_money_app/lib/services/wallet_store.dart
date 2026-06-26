import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/performance_config.dart';
import '../models/app_notification.dart';
import '../models/recipient.dart';
import '../models/transaction_record.dart';
import '../utils/phone_utils.dart';
import 'airtel_api.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'app_logger.dart';
import 'local_data_store.dart';
import 'notification_center.dart';

/// Résultat d'une tentative d'envoi d'argent.
class SendResult {
  const SendResult({required this.success, required this.message, this.tx});

  final bool success;
  final String message;
  final TransactionRecord? tx;
}

/// État global utilisateur + portefeuille avec cache mémoire/disque et SWR.
class WalletStore extends ChangeNotifier {
  WalletStore._();

  static final WalletStore instance = WalletStore._();

  final _api = AirtelApi.instance;

  String ownerId = '';
  String ownerName = '';
  String ownerPhone = '';
  String ownerPayId = '';

  double _balanceUsd = 0;
  double _balanceCdf = 0;
  bool _globalLoading = false;
  bool _walletRefreshing = false;
  bool _transactionsRefreshing = false;
  String? _error;

  bool _hasWalletData = false;
  bool _hasTransactionsData = false;
  bool _hydratedFromDisk = false;

  DateTime? _walletFetchedAt;
  DateTime? _transactionsFetchedAt;
  DateTime? _profileFetchedAt;
  DateTime? _qrFetchedAt;
  Map<String, dynamic>? _qrCache;

  final List<TransactionRecord> _transactions = [];
  Timer? _notifyTimer;

  double get balanceUsd => _balanceUsd;
  double get balanceCdf => _balanceCdf;
  bool get isLoading => _globalLoading;
  bool get walletRefreshing => _walletRefreshing;
  bool get transactionsRefreshing => _transactionsRefreshing;
  bool get hasWalletData => _hasWalletData;
  bool get hasTransactionsData => _hasTransactionsData;
  bool get hasDashboardData => _hasWalletData || _hasTransactionsData;
  bool get dashboardLoading =>
      !_hasWalletData && (_walletRefreshing || _globalLoading);
  String? get error => _error;
  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);

  bool get isLoggedIn => ApiClient.instance.isAuthenticated && ownerId.isNotEmpty;

  Map<String, dynamic>? get cachedQr => _qrCache;

  /// Charge le cache disque (instantané) avant tout appel réseau.
  Future<void> hydrateFromDisk() async {
    if (_hydratedFromDisk) return;

    final profile = await LocalDataStore.loadProfile();
    if (profile != null) {
      ownerId = profile['id']!;
      ownerName = profile['name']!;
      ownerPhone = profile['phone']!;
    }

    final wallet = await LocalDataStore.loadWallet();
    if (wallet != null) {
      _balanceUsd = wallet.usd;
      _balanceCdf = wallet.cdf;
      _hasWalletData = true;
    }

    final txs = await LocalDataStore.loadTransactions();
    if (txs.isNotEmpty) {
      _transactions
        ..clear()
        ..addAll(txs);
      _hasTransactionsData = true;
    }

    _qrCache = await LocalDataStore.loadQr();
    _hydratedFromDisk = true;
    _notifyListenersDebounced();
  }

  /// Restaure la session : cache disque → réseau (non bloquant si cache présent).
  Future<bool> restoreSession() async {
    await ApiClient.instance.init();
    await hydrateFromDisk();
    if (!ApiClient.instance.isAuthenticated) return false;

    if (hasDashboardData && ownerId.isNotEmpty) {
      unawaited(
        refreshAll(force: true).catchError((_) => null),
      );
      return true;
    }

    try {
      await refreshAll(force: true);
      return ownerId.isNotEmpty;
    } catch (_) {
      if (hasDashboardData && ownerId.isNotEmpty) return true;
      await ApiClient.instance.clearTokens();
      await LocalDataStore.clearAll();
      return false;
    }
  }

  Future<void> login(String phone, String pin) async {
    final normalizedPhone = normalizePhone(phone);
    try {
      await _api.login(phone: normalizedPhone, pin: pin.trim());
      _error = null;
      // Navigation immédiate : profil et wallet se chargent ensuite.
      unawaited(_syncAfterLogin());
    } catch (e) {
      _error = e is ApiException ? e.message : 'Connexion impossible';
      AppLogger.error('WalletStore', 'Échec login', error: e);
      rethrow;
    }
  }

  Future<void> _syncAfterLogin() async {
    try {
      await _loadProfile(force: true);
      await refreshWallet(force: true);
      unawaited(refreshTransactions(force: true));
    } catch (e, st) {
      AppLogger.error(
        'WalletStore',
        'Sync post-login échouée',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> logout() async {
    await _api.logout();
    ownerId = '';
    ownerName = '';
    ownerPhone = '';
    ownerPayId = '';
    _balanceUsd = 0;
    _balanceCdf = 0;
    _hasWalletData = false;
    _hasTransactionsData = false;
    _qrCache = null;
    _walletFetchedAt = null;
    _transactionsFetchedAt = null;
    _profileFetchedAt = null;
    _qrFetchedAt = null;
    _transactions.clear();
    await LocalDataStore.clearAll();
    _notifyListenersDebounced();
  }

  /// SWR : affiche le cache, rafraîchit en arrière-plan si TTL expiré.
  Future<void> ensureDashboardFresh() {
    if (hasDashboardData && !_isWalletStale && !_isTransactionsStale) {
      return Future.value();
    }
    if (hasDashboardData) {
      return refreshDashboard(silent: true);
    }
    return refreshDashboard();
  }

  /// Rafraîchit wallet + transactions en parallèle (1 seule notification UI).
  Future<void> refreshDashboard({bool silent = false, bool force = false}) async {
    if (!silent) {
      _walletRefreshing = !_hasWalletData;
      _transactionsRefreshing = !_hasTransactionsData;
      _notifyListenersDebounced();
    }

    try {
      await Future.wait([
        refreshWallet(force: force, silent: true),
        refreshTransactions(force: force, silent: true),
      ]);
      _error = null;
    } catch (e) {
      if (!hasDashboardData) {
        _error = e is ApiException ? e.message : 'Chargement impossible';
      }
    } finally {
      _walletRefreshing = false;
      _transactionsRefreshing = false;
      _notifyListenersDebounced();
    }
  }

  Future<void> refreshAll({bool force = false}) async {
    if (!_isProfileStale && !force && ownerId.isNotEmpty) {
      await refreshDashboard(force: force);
      return;
    }

    _globalLoading = !hasDashboardData;
    _notifyListenersDebounced();

    try {
      await _loadProfile(force: force);
      await refreshDashboard(force: true, silent: hasDashboardData);
      _error = null;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Synchronisation impossible';
      rethrow;
    } finally {
      _globalLoading = false;
      _notifyListenersDebounced();
    }
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (!force && !_isProfileStale && ownerId.isNotEmpty) return;

    final profile = await _api.getProfile();
    ownerId = profile['id'] as String;
    ownerName = profile['fullName'] as String;
    ownerPhone = _formatPhone(profile['phone'] as String);
    _profileFetchedAt = DateTime.now();

    await LocalDataStore.saveProfile(
      id: ownerId,
      name: ownerName,
      phone: ownerPhone,
    );
  }

  Future<void> refreshWallet({bool force = false, bool silent = false}) async {
    if (!force && !_isWalletStale && _hasWalletData) return;

    if (!silent && !_hasWalletData) {
      _walletRefreshing = true;
      _notifyListenersDebounced();
    }

    try {
      final wallet = await _api.getWallet();
      _balanceUsd = (wallet['balance_usd'] as num).toDouble();
      _balanceCdf = (wallet['balance_cdf'] as num).toDouble();
      _hasWalletData = true;
      _walletFetchedAt = DateTime.now();

      await LocalDataStore.saveWallet(
        balanceUsd: _balanceUsd,
        balanceCdf: _balanceCdf,
      );
    } finally {
      if (!silent) {
        _walletRefreshing = false;
        _notifyListenersDebounced();
      }
    }
  }

  Future<void> refreshTransactions({
    bool force = false,
    bool silent = false,
  }) async {
    if (ownerId.isEmpty) return;
    if (!force && !_isTransactionsStale && _hasTransactionsData) return;

    if (!silent && !_hasTransactionsData) {
      _transactionsRefreshing = true;
      _notifyListenersDebounced();
    }

    try {
      final fresh = await _api.getHistory(ownerId);
      _transactions
        ..clear()
        ..addAll(fresh);
      _hasTransactionsData = true;
      _transactionsFetchedAt = DateTime.now();

      await LocalDataStore.saveTransactions(_transactions);
    } finally {
      if (!silent) {
        _transactionsRefreshing = false;
        _notifyListenersDebounced();
      }
    }
  }

  Future<Map<String, dynamic>> fetchMyQr({bool force = false}) async {
    if (!force &&
        _qrCache != null &&
        _qrFetchedAt != null &&
        DateTime.now().difference(_qrFetchedAt!) < PerformanceConfig.qrTtl) {
      return _qrCache!;
    }

    final data = await _api.getMyQr();
    _qrCache = data;
    _qrFetchedAt = DateTime.now();
    await LocalDataStore.saveQr(data);
    return data;
  }

  Future<Recipient> resolveQr(String payId) => _api.resolveQr(payId);

  Future<SendResult> send({
    required Recipient recipient,
    required double amount,
    required String currency,
    String? note,
    required String idempotencyKey,
  }) async {
    if (recipient.userId.isEmpty) {
      return const SendResult(
        success: false,
        message: 'Destinataire invalide (user_id manquant).',
      );
    }

    try {
      final data = await _api.sendMoney(
        receiverId: recipient.userId,
        amount: amount,
        currency: currency,
        idempotencyKey: idempotencyKey,
      );

      await refreshDashboard(force: true, silent: true);

      final tx = TransactionRecord(
        id: data['id'] as String,
        counterpartyName: recipient.name,
        amount: amount,
        currency: currency,
        direction: TxDirection.outgoing,
        status: TxStatus.success,
        date: DateTime.parse(data['created_at'] as String),
        note: note ?? data['reference'] as String?,
      );

      _notify(
        title: 'Transaction réussie',
        message:
            'Vous avez envoyé ${amount.toStringAsFixed(2)} $currency à ${recipient.name}.',
        type: NotificationType.transactionSuccess,
      );

      return SendResult(success: true, message: 'Transfert effectué', tx: tx);
    } on ApiException catch (e) {
      _notify(
        title: 'Transaction échouée',
        message: e.message,
        type: NotificationType.transactionFailed,
      );
      return SendResult(success: false, message: e.message);
    }
  }

  bool get _isWalletStale =>
      _walletFetchedAt == null ||
      DateTime.now().difference(_walletFetchedAt!) > PerformanceConfig.walletTtl;

  bool get _isTransactionsStale =>
      _transactionsFetchedAt == null ||
      DateTime.now().difference(_transactionsFetchedAt!) >
          PerformanceConfig.transactionsTtl;

  bool get _isProfileStale =>
      _profileFetchedAt == null ||
      DateTime.now().difference(_profileFetchedAt!) >
          PerformanceConfig.profileTtl;

  void _notifyListenersDebounced() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(PerformanceConfig.notifyDebounce, () {
      if (hasListeners) notifyListeners();
    });
  }

  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) return digits.substring(digits.length - 9);
    return digits;
  }

  void _notify({
    required String title,
    required String message,
    required NotificationType type,
  }) {
    NotificationCenter.instance.push(
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        message: message,
        date: DateTime.now(),
        type: type,
      ),
    );
  }
}

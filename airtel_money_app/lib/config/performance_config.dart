/// Paramètres réseau et délais de l'application.
class PerformanceConfig {
  PerformanceConfig._();

  /// Durée pendant laquelle les données wallet/transactions restent « fraîches ».
  static const Duration walletTtl = Duration(seconds: 45);
  static const Duration transactionsTtl = Duration(seconds: 45);
  static const Duration qrTtl = Duration(minutes: 5);
  static const Duration profileTtl = Duration(minutes: 10);

  /// Timeouts réseau HTTP (Dio).
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration healthProbeTimeout = Duration(seconds: 5);

  /// Timeout global des opérations utilisateur.
  static const Duration loginTimeout = Duration(seconds: 45);
  static const Duration sessionRestoreTimeout = Duration(seconds: 30);
  static const Duration connectionResolveTimeout = Duration(seconds: 12);
  static const Duration connectionCacheTtl = Duration(seconds: 30);

  /// Retry sur erreurs transitoires réseau.
  static const int maxRetries = 2;
  static const Duration retryBaseDelay = Duration(milliseconds: 500);

  /// Debounce des notifications UI (évite les rebuilds en rafale).
  static const Duration notifyDebounce = Duration(milliseconds: 16);
}

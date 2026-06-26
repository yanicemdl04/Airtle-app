import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/performance_config.dart';
import '../constants/colors.dart';
import '../services/api_exception.dart';
import '../services/app_logger.dart';
import '../services/connection_service.dart';
import '../services/wallet_store.dart';
import '../widgets/server_config_sheet.dart';
import 'main_shell.dart';

/// Comptes de démonstration (seed backend).
const _demoAccounts = [
  (label: 'Alice', phone: '+243999939477', pin: '1234'),
  (label: 'Bob', phone: '+243888112233', pin: '1234'),
];

/// Écran de connexion — authentification via POST /auth/login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _connection = ConnectionService.instance;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_onConnectionChanged);
    _connection.resolveBestUrl();
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionChanged);
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onConnectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshServerStatus() async {
    await _connection.resolveBestUrl(force: true);
  }

  Future<void> _openServerConfig() async {
    await showServerConfigSheet(context);
  }

  void _fillDemoAccount(String phone, String pin) {
    _phoneController.text = phone;
    _pinController.text = pin;
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final serverOk = await _connection.resolveBestUrl(force: true);
      if (!serverOk) {
        throw ApiException(
          _connection.lastError ??
              'Serveur inaccessible. Démarrez le backend (npm run start:dev).',
          isNetworkError: true,
        );
      }

      await WalletStore.instance
          .login(
            _phoneController.text.trim(),
            _pinController.text.trim(),
          )
          .timeout(
            PerformanceConfig.loginTimeout,
            onTimeout: () => throw ApiException(
              'Délai dépassé. Backend : ${_connection.activeUrl ?? "inconnu"}',
              isNetworkError: true,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on ApiException catch (e, st) {
      AppLogger.error('Login', e.message, error: e, stackTrace: st);
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      AppLogger.error('Login', 'Connexion impossible', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = 'Connexion impossible. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildServerBanner() {
    final connected = _connection.isConnected;
    final resolving = _connection.isResolving;
    final bg = connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final fg = connected ? const Color(0xFF2E7D32) : AppColors.primaryRed;
    final icon = connected ? Icons.check_circle_outline : Icons.error_outline;

    String text;
    if (resolving) {
      text = 'Recherche du serveur…';
    } else if (connected) {
      text = 'Serveur OK · ${_connection.latencyMs}ms · ${_connection.activeUrl}';
    } else {
      text = _connection.lastError ??
          'Serveur inaccessible — cd backend && npm run start:dev';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openServerConfig,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: fg, fontSize: 12, height: 1.3),
                ),
              ),
              if (!resolving)
                IconButton(
                  icon: Icon(Icons.refresh, color: fg, size: 20),
                  onPressed: _refreshServerStatus,
                  tooltip: 'Retester le serveur',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildServerBanner(),
                const SizedBox(height: 6),
                Text(
                  'Appuyez sur le bandeau pour configurer l\'URL du serveur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'airtel money',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connectez-vous pour accéder à votre portefeuille',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Numéro de téléphone'),
                  validator: (v) =>
                      v == null || v.trim().length < 8
                          ? 'Numéro invalide'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                  decoration: _decoration('Code PIN'),
                  validator: (v) =>
                      v == null || v.length < 4 ? 'PIN à 4-6 chiffres' : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Comptes de démo (PIN 1234)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final account in _demoAccounts)
                      ActionChip(
                        label: Text(account.label),
                        avatar: const Icon(Icons.person_outline, size: 18),
                        onPressed: _submitting
                            ? null
                            : () => _fillDemoAccount(
                                  account.phone,
                                  account.pin,
                                ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

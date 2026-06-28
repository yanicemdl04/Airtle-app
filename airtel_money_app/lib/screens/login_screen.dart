import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/colors.dart';
import '../services/api_exception.dart';
import '../services/app_logger.dart';
import '../services/auth_service.dart';
import '../services/connection_service.dart';
import '../widgets/server_config_sheet.dart';
import 'main_shell.dart';

/// Comptes de démonstration (seed backend).
const _demoAccounts = [
  (label: 'Alice', phone: '+243999939477', pin: '1234'),
  (label: 'Bob', phone: '+243888112233', pin: '1234'),
];

/// Écran de connexion — POST /api/auth/login via [AuthService].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _auth = AuthService.instance;
  final _connection = ConnectionService.instance;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_onConnectionChanged);
    unawaited(_connection.ensureConnected());
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (!_connection.isConnected) {
        final serverOk = await _connection.ensureConnected(force: true);
        if (!serverOk) {
          throw ApiException(
            _connection.lastError ??
                'Serveur inaccessible. Démarrez PostgreSQL puis le backend.',
            isNetworkError: true,
          );
        }
      }

      await _auth.login(
        _phoneController.text.trim(),
        _pinController.text.trim(),
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

  void _fillDemo(String phone, String pin) {
    _phoneController.text = phone;
    _pinController.text = pin;
    setState(() => _error = null);
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
                const SizedBox(height: 16),
                _ServerBanner(connection: _connection),
                const SizedBox(height: 24),
                const _LoginHeader(),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Numéro de téléphone'),
                  validator: (v) =>
                      v == null || v.trim().length < 8 ? 'Numéro invalide' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration('Code PIN'),
                  validator: (v) =>
                      v == null || v.length < 4 ? 'PIN à 4-6 chiffres' : null,
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final a in _demoAccounts)
                      ActionChip(
                        label: Text(a.label),
                        onPressed:
                            _submitting ? null : () => _fillDemo(a.phone, a.pin),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primaryRed),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
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
      ],
    );
  }
}

class _ServerBanner extends StatelessWidget {
  const _ServerBanner({required this.connection});

  final ConnectionService connection;

  @override
  Widget build(BuildContext context) {
    final connected = connection.isConnected;
    final bg = connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final fg = connected ? const Color(0xFF2E7D32) : AppColors.primaryRed;

    final text = connection.isResolving
        ? 'Recherche du serveur…'
        : connected
            ? 'Serveur OK · ${connection.latencyMs}ms · ${connection.activeUrl}'
            : connection.lastError ??
                'Serveur inaccessible — npm run start:dev dans backend/';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showServerConfigSheet(context),
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
              Icon(
                connected ? Icons.check_circle_outline : Icons.error_outline,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(color: fg, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

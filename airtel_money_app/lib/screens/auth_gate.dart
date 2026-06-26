import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../config/performance_config.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/connection_service.dart';
import '../services/wallet_store.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Porte d'entrée : restaure la session ou affiche le login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ApiClient.instance.init();

    // Résolution URL en arrière-plan — le login reteste avant connexion.
    unawaited(ConnectionService.instance.resolveBestUrl());

    try {
      final ok = await WalletStore.instance
          .restoreSession()
          .timeout(
            PerformanceConfig.sessionRestoreTimeout,
            onTimeout: () => false,
          );
      if (mounted) {
        setState(() {
          _authenticated = ok;
          _checking = false;
        });
      }
    } catch (e, st) {
      AppLogger.error('AuthGate', 'Échec restauration session', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _authenticated = false;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }

    return _authenticated ? const MainShell() : const LoginScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../services/api_exception.dart';
import '../services/toast_service.dart';
import '../services/wallet_store.dart';
import '../widgets/animated_button.dart';
import '../widgets/glass_container.dart';
import '../widgets/qr_display.dart';
import '../widgets/shimmer_loading.dart';

/// Écran « Mon QR » — affichage premium avec glassmorphism.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WalletStore.instance.addListener(_onStoreChanged);
    _load(force: WalletStore.instance.cachedQr == null);
  }

  @override
  void dispose() {
    WalletStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted && WalletStore.instance.cachedQr != null && _loading) {
      setState(() {
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _load({bool force = false}) async {
    if (WalletStore.instance.cachedQr != null && !force) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletStore.instance.fetchMyQr(force: true);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger le QR : $e';
          _loading = false;
        });
      }
    }
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, 3)} ••• ${phone.substring(phone.length - 3)}';
  }

  void _share(Map<String, dynamic>? qrData) {
    final payId = qrData?['pay_id']?.toString();
    if (payId == null || payId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: payId));
    ToastService.success(
      context,
      'Copié',
      message: 'Identifiant de paiement copié dans le presse-papiers',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Mon QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => _load(force: true),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: WalletStore.instance,
        builder: (context, _) {
          final store = WalletStore.instance;
          final qrData = store.cachedQr;

          if (_loading && qrData == null) {
            return const Center(child: BalanceShimmer());
          }

          if (_error != null && qrData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.primaryRed),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedButton(
                      label: 'Réessayer',
                      onPressed: () => _load(force: true),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Text(
                        store.ownerName.isNotEmpty
                            ? store.ownerName
                            : 'Mon compte',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 4),
                      Text(
                        _maskedPhone(store.ownerPhone),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QrDisplay(qrData: qrData)
                          .animate(delay: 100.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                            curve: Curves.elasticOut,
                          ),
                      const SizedBox(height: 12),
                      const Text(
                        'Faites scanner ce code pour recevoir un paiement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedButton(
                        label: 'Partager',
                        icon: Icons.share_rounded,
                        secondary: true,
                        onPressed: qrData == null ? () {} : () => _share(qrData),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

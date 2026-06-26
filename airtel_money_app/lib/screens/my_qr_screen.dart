import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../services/api_exception.dart';
import '../services/toast_service.dart';
import '../services/wallet_store.dart';
import '../widgets/animated_button.dart';
import '../widgets/glass_container.dart';
import '../widgets/shimmer_loading.dart';

/// Écran « Mon QR » — affichage premium avec glassmorphism.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  Map<String, dynamic>? _qrData;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _qrData = WalletStore.instance.cachedQr;
    _load(showCacheFirst: _qrData != null);
  }

  Future<void> _load({bool showCacheFirst = false, bool force = false}) async {
    if (!showCacheFirst) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await WalletStore.instance.fetchMyQr(force: force);
      if (mounted) {
        setState(() {
          _qrData = data;
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
    }
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, 3)} ••• ${phone.substring(phone.length - 3)}';
  }

  void _share() {
    if (_qrData == null) return;
    Clipboard.setData(
      ClipboardData(text: _qrData!['pay_id'] as String),
    );
    ToastService.success(
      context,
      'Copié',
      message: 'Identifiant de paiement copié dans le presse-papiers',
    );
  }

  void _download() {
    ToastService.info(
      context,
      'Téléchargement',
      message: 'Fonctionnalité disponible prochainement',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = WalletStore.instance;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Mon QR')),
      body: _loading && _qrData == null
          ? const Center(child: BalanceShimmer())
          : _error != null
              ? Center(
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
                        AnimatedButton(label: 'Réessayer', onPressed: () => _load(force: true)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    children: [
                      GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              store.ownerName,
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
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.cardRadius),
                              ),
                              child: QrImageView(
                                data: jsonEncode(_qrData!['qr_content']),
                                version: QrVersions.auto,
                                size: 220,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.primaryRed,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ).animate(delay: 100.ms).scale(
                                  begin: const Offset(0.9, 0.9),
                                  end: const Offset(1, 1),
                                  curve: Curves.elasticOut,
                                ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.redTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _qrData!['pay_id'] as String,
                                style: const TextStyle(
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
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
                              onPressed: _share,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedButton(
                              label: 'Télécharger',
                              icon: Icons.download_rounded,
                              onPressed: _download,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

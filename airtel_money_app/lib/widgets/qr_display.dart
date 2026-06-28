import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/colors.dart';
import '../utils/qr_payload.dart';

/// Affiche le QR de paiement Airtel Money à partir des données API.
class QrDisplay extends StatelessWidget {
  const QrDisplay({
    super.key,
    required this.qrData,
    this.size = 220,
    this.showPayId = true,
    this.onRetry,
  });

  final Map<String, dynamic>? qrData;
  final double size;
  final bool showPayId;

  /// Si fourni, un bouton « Réessayer » est affiché en cas d'absence de données.
  final VoidCallback? onRetry;

  Widget _placeholder(String label, {bool showRetry = false}) {
    return SizedBox(
      height: size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (qrData == null) {
      // Sans bouton de relance, on suppose un chargement en cours.
      if (onRetry == null) {
        return SizedBox(
          height: size,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return _placeholder('QR indisponible', showRetry: true);
    }

    String payload;
    try {
      payload = buildQrPayload(qrData!);
    } catch (e) {
      return _placeholder('QR indisponible', showRetry: true);
    }

    final payId = qrData!['pay_id']?.toString() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: size,
            gapless: true,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.primaryRed,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.textPrimary,
            ),
            errorStateBuilder: (_, __) => const Icon(
              Icons.qr_code_2_rounded,
              size: 80,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (showPayId && payId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.redTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              payId,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

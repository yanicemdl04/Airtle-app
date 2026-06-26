import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../models/recipient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/wallet_store.dart';
import '../../widgets/animated_button.dart';

/// Écran initial : saisie manuelle du destinataire ou scan QR.
class SendRecipientScreen extends StatefulWidget {
  const SendRecipientScreen({super.key});

  @override
  State<SendRecipientScreen> createState() => _SendRecipientScreenState();
}

class _SendRecipientScreenState extends State<SendRecipientScreen> {
  final _controller = TextEditingController(text: 'airtel:CD:');
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final payId = _controller.text.trim();
    if (!payId.startsWith('airtel:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifiant invalide (airtel:CD:...)')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final recipient = await WalletStore.instance.resolveQr(payId);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.sendFlow,
        arguments: recipient,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.primaryRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Envoyer de l'argent")),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Destinataire',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Saisissez l\'identifiant Airtel Money ou scannez un QR code.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Identifiant de paiement',
                hintText: 'airtel:CD:xxxxxxxx',
                prefixIcon: Icon(Icons.person_search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedButton(
              label: 'Continuer',
              loading: _loading,
              onPressed: _resolve,
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedButton(
              label: 'Scanner un QR',
              secondary: true,
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.scanQr),
            ),
          ],
        ),
      ),
    );
  }
}

/// Données partagées entre les étapes du flux d'envoi.
class SendFlowData {
  SendFlowData({
    required this.recipient,
    this.amount,
    this.currency = 'CDF',
    this.note,
  });

  final Recipient recipient;
  double? amount;
  String currency;
  String? note;
}

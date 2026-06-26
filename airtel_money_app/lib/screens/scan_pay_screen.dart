import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../constants/colors.dart';
import '../models/recipient.dart';
import '../routes/app_routes.dart';
import '../services/api_exception.dart';
import '../services/wallet_store.dart';

/// Écran « Scannez et payez ».
///
/// Détecte le `pay_id` dans le QR puis appelle POST /qr/resolve pour
/// pré-remplir l'écran d'envoi avec les données du bénéficiaire.
class ScanPayScreen extends StatefulWidget {
  const ScanPayScreen({super.key});

  @override
  State<ScanPayScreen> createState() => _ScanPayScreenState();
}

class _ScanPayScreenState extends State<ScanPayScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  bool _resolving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _resolving) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final payId = Recipient.extractPayId(raw);
      if (payId != null) {
        _resolveAndNavigate(payId);
        return;
      }
    }
  }

  Future<void> _resolveAndNavigate(String payId) async {
    if (_handled) return;
    setState(() {
      _handled = true;
      _resolving = true;
    });
    _controller.stop();

    try {
      final recipient = await WalletStore.instance.resolveQr(payId);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.sendFlow,
        arguments: recipient,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _handled = false;
        _resolving = false;
      });
      _controller.start();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController(text: 'airtel:CD:');
    final payId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir un identifiant de paiement'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'airtel:CD:xxxxxxxx',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (payId != null && payId.startsWith('airtel:')) {
      await _resolveAndNavigate(payId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        title: const Text('Scannez et payez'),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_resolving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Résolution du QR…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              children: [
                const Text(
                  'Placez le QR Airtel Money dans le cadre',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _resolving ? null : _manualEntry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Saisir le code manuellement'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

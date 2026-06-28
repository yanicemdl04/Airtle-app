import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../constants/colors.dart';
import '../services/connection_service.dart';

/// Feuille pour configurer et tester l'URL du backend manuellement.
Future<bool?> showServerConfigSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ServerConfigSheet(),
  );
}

class _ServerConfigSheet extends StatefulWidget {
  const _ServerConfigSheet();

  @override
  State<_ServerConfigSheet> createState() => _ServerConfigSheetState();
}

class _ServerConfigSheetState extends State<_ServerConfigSheet> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _result;
  bool? _success;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ConnectionService.instance.activeUrl ?? ApiConfig.baseUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _testing = true;
      _result = null;
      _success = null;
    });

    final ok = await ConnectionService.instance.testManualUrl(url);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _success = ok;
      _result = ok
          ? 'Connexion OK · ${ConnectionService.instance.latencyMs}ms'
          : ConnectionService.instance.lastError ??
              'Impossible de joindre le serveur';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Configurer le serveur API',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${ApiConfig.platformHint}\n\n'
            'ngrok : lancez « ngrok http 3000 », copiez l’URL https affichée, '
            'ajoutez /api à la fin.\n\n'
            'Build APK : ${ApiConfig.apkBuildHint}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'URL du backend',
              hintText: 'https://abc123.ngrok-free.app/api',
              filled: true,
              fillColor: AppColors.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              _result!,
              style: TextStyle(
                color: _success == true
                    ? const Color(0xFF2E7D32)
                    : AppColors.primaryRed,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tester'),
                ),
              ),
            ],
          ),
          if (_success == true) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Utiliser cette URL'),
            ),
          ],
        ],
      ),
    );
  }
}

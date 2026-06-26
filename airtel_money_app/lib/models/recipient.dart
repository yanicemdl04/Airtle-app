import 'dart:convert';

/// Bénéficiaire d'un paiement, obtenu après résolution d'un QR scanné.
///
/// Le QR ne contient que le `pay_id` ; le backend renvoie nom, téléphone masqué
/// et `user_id` via POST /qr/resolve.
class Recipient {
  const Recipient({
    required this.payId,
    required this.name,
    required this.maskedPhone,
    this.userId = '',
  });

  final String payId;
  final String name;
  final String maskedPhone;

  /// UUID du bénéficiaire (requis pour POST /transactions/send).
  final String userId;

  /// Extrait le `pay_id` d'un QR scanné (JSON ou texte brut).
  static String? extractPayId(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded['type'] == 'airtel_money') {
        final payId = decoded['pay_id'];
        if (payId is String && payId.isNotEmpty) return payId;
      }
    } catch (_) {
      // Peut être un pay_id brut : airtel:CD:xxxx
    }
    if (raw.startsWith('airtel:')) return raw.trim();
    return null;
  }

  /// Contenu minimal à encoder dans le QR (conforme backend).
  String toQrPayload() => jsonEncode({
        'type': 'airtel_money',
        'pay_id': payId,
      });

  factory Recipient.fromApi(Map<String, dynamic> data, String payId) {
    return Recipient(
      userId: data['user_id'] as String? ?? '',
      payId: payId,
      name: data['name'] as String? ?? 'Bénéficiaire',
      maskedPhone: data['masked_phone'] as String? ?? '••• •••',
    );
  }
}

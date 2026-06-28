import 'dart:convert';

/// Construit la chaîne à encoder dans le QR à partir de la réponse API.
String buildQrPayload(Map<String, dynamic> data) {
  final root = _unwrap(data);
  final content = root['qr_content'];

  if (content is Map) {
    return jsonEncode(Map<String, dynamic>.from(content));
  }
  if (content is String && content.isNotEmpty) {
    return content;
  }

  final payId = root['pay_id']?.toString();
  if (payId != null && payId.isNotEmpty) {
    return jsonEncode({'type': 'airtel_money', 'pay_id': payId});
  }

  throw FormatException('Réponse QR invalide : $root');
}

Map<String, dynamic> _unwrap(Map<String, dynamic> data) {
  final nested = data['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return data;
}

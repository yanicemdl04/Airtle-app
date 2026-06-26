/// Exception levée lors d'un appel API échoué.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  @override
  String toString() => message;
}

/// Extrait le champ `data` de l'enveloppe `{ success, data }` du backend.
Map<String, dynamic> unwrapData(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    if (responseData.containsKey('data')) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'items': data};
    }
    return responseData;
  }
  throw ApiException('Réponse API invalide');
}

List<Map<String, dynamic>> unwrapList(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    final data = responseData['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }
  if (responseData is List) {
    return responseData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return [];
}

String extractErrorMessage(dynamic errorBody) {
  if (errorBody is Map) {
    final message = errorBody['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) return message.first.toString();
  }
  return 'Erreur réseau ou serveur indisponible';
}

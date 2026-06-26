import '../config/api_config.dart';
import '../models/recipient.dart';
import '../models/transaction_record.dart';
import 'api_client.dart';

/// Façade des appels REST vers le backend NestJS.
class AirtelApi {
  AirtelApi._();

  static final AirtelApi instance = AirtelApi._();
  final _client = ApiClient.instance;

  Future<Map<String, String>> login({
    required String phone,
    required String pin,
  }) async {
    final data = await _client.post('/auth/login', data: {
      'phone': phone,
      'pin': pin,
      'deviceId': ApiConfig.deviceId,
    });
    await _client.setTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return {
      'access_token': data['access_token'] as String,
      'refresh_token': data['refresh_token'] as String,
    };
  }

  Future<void> logout() => _client.clearTokens();

  Future<Map<String, dynamic>> getProfile() => _client.get('/users/profile');

  Future<Map<String, dynamic>> getWallet() => _client.get('/wallet');

  Future<Map<String, dynamic>> getMyQr() => _client.get('/qr/my');

  Future<Recipient> resolveQr(String payId) async {
    final data = await _client.post('/qr/resolve', data: {'pay_id': payId});
    return Recipient(
      userId: data['user_id'] as String,
      payId: payId,
      name: data['name'] as String,
      maskedPhone: data['masked_phone'] as String,
    );
  }

  Future<Map<String, dynamic>> sendMoney({
    required String receiverId,
    required double amount,
    required String currency,
    required String idempotencyKey,
  }) {
    return _client.post('/transactions/send', data: {
      'receiver_id': receiverId,
      'amount': amount,
      'currency': currency,
      'idempotency_key': idempotencyKey,
    });
  }

  Future<List<TransactionRecord>> getHistory(String currentUserId) async {
    final items = await _client.getList('/transactions/history');
    return items.map((t) => _mapTransaction(t, currentUserId)).toList();
  }

  TransactionRecord _mapTransaction(
    Map<String, dynamic> t,
    String currentUserId,
  ) {
    final direction = t['direction'] == 'OUT'
        ? TxDirection.outgoing
        : TxDirection.incoming;

    final statusStr = (t['status'] as String?) ?? 'PENDING';
    final status = switch (statusStr) {
      'SUCCESS' => TxStatus.success,
      'FAILED' => TxStatus.failed,
      _ => TxStatus.pending,
    };

    return TransactionRecord(
      id: t['id'] as String,
      counterpartyName: (t['counterparty_name'] as String?) ??
          (direction == TxDirection.outgoing ? 'Destinataire' : 'Expéditeur'),
      amount: (t['amount'] as num).toDouble(),
      currency: t['currency'] as String,
      direction: direction,
      status: status,
      date: DateTime.parse(t['created_at'] as String),
      note: t['reference'] as String?,
    );
  }
}

/// Sens d'une transaction du point de vue de l'utilisateur courant.
enum TxDirection { outgoing, incoming }

/// Statut d'une transaction.
enum TxStatus { success, pending, failed }

/// Représentation locale d'une transaction (côté application).
class TransactionRecord {
  TransactionRecord({
    required this.id,
    required this.counterpartyName,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    required this.date,
    this.note,
  });

  final String id;
  final String counterpartyName;
  final double amount;
  final String currency;
  final TxDirection direction;
  final TxStatus status;
  final DateTime date;
  final String? note;

  String get signedAmount {
    final sign = direction == TxDirection.outgoing ? '-' : '+';
    return '$sign ${amount.toStringAsFixed(2)} $currency';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'counterpartyName': counterpartyName,
        'amount': amount,
        'currency': currency,
        'direction': direction.name,
        'status': status.name,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      counterpartyName: json['counterpartyName'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      direction: TxDirection.values.byName(json['direction'] as String),
      status: TxStatus.values.byName(json['status'] as String),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }
}

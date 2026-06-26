import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../models/transaction_record.dart';
import '../../widgets/airtel_card.dart';

/// Détail d'une transaction.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final TransactionRecord transaction;

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  String _statusLabel() {
    switch (transaction.status) {
      case TxStatus.success:
        return 'Réussie';
      case TxStatus.pending:
        return 'En attente';
      case TxStatus.failed:
        return 'Échouée';
    }
  }

  Color _statusColor() {
    switch (transaction.status) {
      case TxStatus.success:
        return AppColors.success;
      case TxStatus.pending:
        return AppColors.info;
      case TxStatus.failed:
        return AppColors.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail transaction')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            AirtelCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _statusColor().withValues(alpha: 0.12),
                    child: Icon(
                      transaction.direction == TxDirection.outgoing
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: _statusColor(),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    transaction.signedAmount,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow('Contrepartie', transaction.counterpartyName),
                  _DetailRow('Date', _formatDate(transaction.date)),
                  _DetailRow('Référence', transaction.id),
                  if (transaction.note != null)
                    _DetailRow('Motif', transaction.note!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

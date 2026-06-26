import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../models/transaction_record.dart';

/// Carte transaction pour listes (accueil, historique).
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.compact = false,
  });

  final TransactionRecord transaction;
  final VoidCallback? onTap;
  final bool compact;

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor() {
    switch (transaction.status) {
      case TxStatus.success:
        return transaction.direction == TxDirection.outgoing
            ? AppColors.primaryRed
            : AppColors.success;
      case TxStatus.pending:
        return AppColors.info;
      case TxStatus.failed:
        return AppColors.textMuted;
    }
  }

  IconData _icon() {
    if (transaction.status == TxStatus.failed) {
      return Icons.close_rounded;
    }
    return transaction.direction == TxDirection.outgoing
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: compact ? 20 : 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_icon(), color: color, size: compact ? 18 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.counterpartyName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: compact ? 13.5 : 14,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        transaction.note ?? 'Transfert Airtel Money',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(transaction.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                transaction.signedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

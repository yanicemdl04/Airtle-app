import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../models/transaction_record.dart';
import '../../routes/app_routes.dart';
import '../../services/wallet_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';

enum TxFilter { all, received, sent, failed }

/// Historique des transactions avec filtres.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TxFilter _filter = TxFilter.all;

  Future<void> _refresh() =>
      WalletStore.instance.refreshTransactions(force: true);

  List<TransactionRecord> _filtered(List<TransactionRecord> all) {
    switch (_filter) {
      case TxFilter.received:
        return all
            .where((t) => t.direction == TxDirection.incoming)
            .toList();
      case TxFilter.sent:
        return all
            .where((t) => t.direction == TxDirection.outgoing)
            .toList();
      case TxFilter.failed:
        return all.where((t) => t.status == TxStatus.failed).toList();
      case TxFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              topPadding + AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, AppColors.primaryRedDark],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppSpacing.md),
                bottomRight: Radius.circular(AppSpacing.md),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'Historique',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tout',
                  selected: _filter == TxFilter.all,
                  onTap: () => setState(() => _filter = TxFilter.all),
                ),
                _FilterChip(
                  label: 'Reçu',
                  selected: _filter == TxFilter.received,
                  onTap: () => setState(() => _filter = TxFilter.received),
                ),
                _FilterChip(
                  label: 'Envoyé',
                  selected: _filter == TxFilter.sent,
                  onTap: () => setState(() => _filter = TxFilter.sent),
                ),
                _FilterChip(
                  label: 'Échec',
                  selected: _filter == TxFilter.failed,
                  onTap: () => setState(() => _filter = TxFilter.failed),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListenableBuilder(
              listenable: WalletStore.instance,
              builder: (context, _) {
                final store = WalletStore.instance;
                if (store.transactionsRefreshing && !store.hasTransactionsData) {
                  return const TransactionListShimmer(count: 5);
                }

                final txs = _filtered(store.transactions);
                if (txs.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune transaction',
                    subtitle:
                        'Vous n\'avez encore effectué aucune transaction',
                    actionLabel: 'Envoyer de l\'argent',
                    onAction: () =>
                        Navigator.pushNamed(context, AppRoutes.sendMoney),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primaryRed,
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: txs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => RepaintBoundary(
                      child: TransactionCard(
                        transaction: txs[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.transactionDetail,
                          arguments: txs[index],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.redTint,
        checkmarkColor: AppColors.primaryRed,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryRed : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected ? AppColors.primaryRed : AppColors.divider,
        ),
      ),
    );
  }
}

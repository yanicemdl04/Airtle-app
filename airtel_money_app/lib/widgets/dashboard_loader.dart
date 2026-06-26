import 'package:flutter/material.dart';

import '../services/wallet_store.dart';
import '../widgets/shimmer_loading.dart';

/// Écoute [WalletStore] et n'affiche le shimmer que si aucune donnée en cache.
class DashboardLoader extends StatelessWidget {
  const DashboardLoader({
    super.key,
    required this.builder,
    this.shimmer = const BalanceShimmer(),
  });

  final Widget Function(BuildContext context, WalletStore store) builder;
  final Widget shimmer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final store = WalletStore.instance;
        if (store.dashboardLoading) return shimmer;
        return builder(context, store);
      },
    );
  }
}

/// Indicateur discret de synchronisation en arrière-plan.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final store = WalletStore.instance;
        final syncing = store.walletRefreshing || store.transactionsRefreshing;
        if (!syncing) return const SizedBox.shrink();

        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

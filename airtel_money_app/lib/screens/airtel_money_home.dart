import 'package:flutter/material.dart';

import '../animations/stagger_animation.dart';
import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../routes/app_routes.dart';
import '../services/notification_center.dart';
import '../services/toast_service.dart';
import '../services/wallet_store.dart';
import '../widgets/app_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/section_header.dart';
import '../widgets/service_tile.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/transaction_card.dart';
import 'transactions/transactions_screen.dart';

/// Onglet « Airtel Money » : wallet, services et transactions.
class AirtelMoneyHomePage extends StatefulWidget {
  const AirtelMoneyHomePage({super.key});

  @override
  State<AirtelMoneyHomePage> createState() => _AirtelMoneyHomePageState();
}

class _AirtelMoneyHomePageState extends State<AirtelMoneyHomePage> {
  Future<void> _refresh() => WalletStore.instance.refreshDashboard(force: true);

  void _openScan() => Navigator.pushNamed(context, AppRoutes.scanQr);
  void _openMyQr() => Navigator.pushNamed(context, AppRoutes.myQr);
  void _openSend() => Navigator.pushNamed(context, AppRoutes.sendMoney);
  void _openNotifications() =>
      Navigator.pushNamed(context, AppRoutes.notifications);
  void _openTransactions() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
      );

  void _comingSoon(String label) {
    ToastService.info(context, label, message: 'Bientôt disponible');
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final scrollTopPadding = 120 + topPadding - 44;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primaryRed,
            onRefresh: _refresh,
            child: ListenableBuilder(
              listenable: WalletStore.instance,
              builder: (context, _) {
                final store = WalletStore.instance;
                final initialLoad = store.dashboardLoading;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(top: scrollTopPadding, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (initialLoad)
                        const BalanceShimmer()
                      else
                        BalanceCard(
                          name: store.ownerName,
                          phone: store.ownerPhone,
                          onMyQrTap: _openMyQr,
                          onCredit: () => _comingSoon('Créditer son compte'),
                          onWithdraw: () => _comingSoon("Retirer de l'argent"),
                        ).staggerFadeSlide(index: 0),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Transfert et Retrait',
                      ).staggerFadeSlide(index: 1),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: ServiceTile(
                                icon: Icons.send_rounded,
                                label: "Envoyer de l'argent",
                                onTap: _openSend,
                              ),
                            ),
                            Expanded(
                              child: ServiceTile(
                                icon: Icons.local_atm_rounded,
                                label: "Retirer de l'argent",
                                onTap: () => _comingSoon("Retirer de l'argent"),
                              ),
                            ),
                            Expanded(
                              child: ServiceTile(
                                icon: Icons.add_card_outlined,
                                label: 'Créditer compte',
                                onTap: () => _comingSoon('Créditer son compte'),
                              ),
                            ),
                          ],
                        ),
                      ).staggerFadeSlide(index: 2),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Recharge et Factures',
                      ).staggerFadeSlide(index: 3),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 0.78,
                          children: [
                            ServiceTile(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Scannez et payez',
                              onTap: _openScan,
                            ),
                            ServiceTile(
                              icon: Icons.receipt_long_outlined,
                              label: 'Factures',
                              onTap: () => _comingSoon('Paiement de factures'),
                            ),
                            ServiceTile(
                              icon: Icons.sim_card_outlined,
                              label: 'Forfaits',
                              onTap: () => _comingSoon('Forfaits'),
                            ),
                            ServiceTile(
                              icon: Icons.phone_android_outlined,
                              label: 'Recharger',
                              onTap: () => _comingSoon('Recharger'),
                            ),
                          ],
                        ),
                      ).staggerFadeSlide(index: 4),
                      const SizedBox(height: AppSpacing.sm),
                      if (initialLoad)
                        const PromoCarouselShimmer()
                      else
                        const PromoCarousel().staggerFadeSlide(index: 5),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Transactions récentes',
                        actionLabel: 'Voir tout',
                        onAction: _openTransactions,
                      ).staggerFadeSlide(index: 6),
                      const SizedBox(height: AppSpacing.xs),
                      const _RecentTxList().staggerFadeSlide(index: 7),
                    ],
                  ),
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: NotificationCenter.instance,
            builder: (context, _) => AppHeader(
              notificationCount: NotificationCenter.instance.unreadCount,
              onQrTap: _openScan,
              onNotificationsTap: _openNotifications,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTxList extends StatelessWidget {
  const _RecentTxList();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final store = WalletStore.instance;
        if (store.transactionsRefreshing && !store.hasTransactionsData) {
          return const TransactionListShimmer(count: 2);
        }

        final txs = store.transactions.take(3).toList();
        if (txs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Aucune transaction récente',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: [
              for (var i = 0; i < txs.length; i++) ...[
                TransactionCard(
                  transaction: txs[i],
                  compact: true,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.transactionDetail,
                    arguments: txs[i],
                  ),
                ),
                if (i < txs.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

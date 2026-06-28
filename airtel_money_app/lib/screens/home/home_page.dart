import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../animations/stagger_animation.dart';
import '../../constants/app_assets.dart';
import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../routes/app_routes.dart';
import '../../services/notification_center.dart';
import '../../services/wallet_store.dart';
import '../../widgets/airtel_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/app_image.dart';
import '../../widgets/promo_carousel.dart';
import '../../widgets/section_header.dart';
import '../../widgets/service_tile.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';
import '../airtel_money_home.dart';
import '../transactions/transactions_screen.dart';

/// Page d'accueil principale — inspirée du design Airtel opérateur,
/// modernisée pour une expérience fintech premium.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _refresh() => WalletStore.instance.refreshDashboard(force: true);

  void _openNotifications() {
    Navigator.of(context).pushNamed(AppRoutes.notifications);
  }

  void _openSendMoney() {
    Navigator.of(context).pushNamed(AppRoutes.sendMoney);
  }

  void _openScan() {
    Navigator.of(context).pushNamed(AppRoutes.scanQr);
  }

  void _openTransactions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
    );
  }

  void _openAirtelMoney() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AirtelMoneyHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final scrollTop = 110 + topPadding - 36;

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
                  padding: EdgeInsets.only(top: scrollTop, bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (initialLoad)
                        const BalanceShimmer()
                      else
                        _ProfileBalanceCard(onManage: _openAirtelMoney)
                            .staggerFadeSlide(index: 0),
                      const SizedBox(height: AppSpacing.sm),
                      _AlertBanner().staggerFadeSlide(index: 1),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Actions rapides',
                        actionLabel: 'Tout afficher',
                        onAction: _openAirtelMoney,
                      ).staggerFadeSlide(index: 2),
                      const SizedBox(height: AppSpacing.xs),
                      _QuickActionsGrid(
                        onSend: _openSendMoney,
                        onScan: _openScan,
                        onAirtelMoney: _openAirtelMoney,
                      ).staggerFadeSlide(index: 3),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 120,
                          child: AppImage(
                            asset: AppAssets.homeBanner,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                          ),
                        ),
                      ).staggerFadeSlide(index: 4),
                      const SizedBox(height: AppSpacing.sm),
                      const PromoCarousel().staggerFadeSlide(index: 5),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Services',
                        actionLabel: 'Voir plus',
                        onAction: _openAirtelMoney,
                      ).staggerFadeSlide(index: 6),
                      const SizedBox(height: AppSpacing.xs),
                      _ServicesGrid(onAirtelMoney: _openAirtelMoney)
                          .staggerFadeSlide(index: 7),
                      const SizedBox(height: AppSpacing.sm),
                      SectionHeader(
                        title: 'Transactions récentes',
                        actionLabel: 'Historique',
                        onAction: _openTransactions,
                      ).staggerFadeSlide(index: 8),
                      const SizedBox(height: AppSpacing.xs),
                      _RecentTransactions(
                        onSend: _openSendMoney,
                      ).staggerFadeSlide(index: 9),
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
              showMoneyBranding: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBalanceCard extends StatefulWidget {
  const _ProfileBalanceCard({required this.onManage});

  final VoidCallback onManage;

  @override
  State<_ProfileBalanceCard> createState() => _ProfileBalanceCardState();
}

class _ProfileBalanceCardState extends State<_ProfileBalanceCard> {
  bool _hidden = false;

  String _fmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ' ',
    );
    return '$intPart,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final store = WalletStore.instance;

    return AirtelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: store.ownerName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.ownerName.isNotEmpty
                          ? store.ownerName
                          : 'Utilisateur Airtel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prépayé · ${store.ownerPhone.isNotEmpty ? store.ownerPhone : '—'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (store.ownerPayId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Compte · ${store.ownerPayId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onManage,
                child: const Text(
                  'GERER',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: WalletStore.instance,
            builder: (context, _) {
              return Row(
                children: [
                  _BalanceColumn(
                    label: 'CDF',
                    value: _hidden ? '••••' : _fmt(store.balanceCdf),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _divider(),
                  _BalanceColumn(
                    label: 'USD',
                    value: _hidden ? '••••' : _fmt(store.balanceUsd),
                    icon: Icons.attach_money_rounded,
                  ),
                  _divider(),
                  _BalanceColumn(
                    label: 'Appels',
                    value: '0 min',
                    icon: Icons.call_outlined,
                    muted: true,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuickPillButton(
                  icon: Icons.sim_card_outlined,
                  label: 'Acheter forfaits',
                  onTap: widget.onManage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickPillButton(
                  icon: Icons.bolt_rounded,
                  label: 'Recharger',
                  onTap: widget.onManage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.divider,
      );
}

class _BalanceColumn extends StatelessWidget {
  const _BalanceColumn({
    required this.label,
    required this.value,
    required this.icon,
    this.muted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: muted ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPillButton extends StatelessWidget {
  const _QuickPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.redTint,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryRed, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AirtelCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.redTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activez Airtel Money',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complétez votre inscription pour envoyer et recevoir de l\'argent.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms);
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onSend,
    required this.onScan,
    required this.onAirtelMoney,
  });

  final VoidCallback onSend;
  final VoidCallback onScan;
  final VoidCallback onAirtelMoney;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.82,
        children: [
          ServiceTile(
            icon: Icons.sim_card_outlined,
            label: 'Forfaits',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.card_giftcard_outlined,
            label: 'Parrainer',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.phone_android_outlined,
            label: 'Recharger',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.wifi_rounded,
            label: 'Airtel 4G',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.send_rounded,
            label: 'Envoyer',
            onTap: onSend,
            badge: 'New',
          ),
          ServiceTile(
            icon: Icons.local_atm_outlined,
            label: 'Retirer',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.add_card_outlined,
            label: 'Créditer',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan QR',
            onTap: onScan,
          ),
        ],
      ),
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.onAirtelMoney});

  final VoidCallback onAirtelMoney;

  @override
  Widget build(BuildContext context) {
    return AirtelCard(
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        children: [
          ServiceTile(
            icon: Icons.receipt_long_outlined,
            label: 'Factures',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.shopping_bag_outlined,
            label: 'Produits',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.star_outline_rounded,
            label: 'Favoris',
            onTap: onAirtelMoney,
          ),
          ServiceTile(
            icon: Icons.volunteer_activism_outlined,
            label: 'RENFORT',
            onTap: onAirtelMoney,
          ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.onSend});

  final VoidCallback onSend;

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
            child: AirtelCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vous n\'avez encore effectué aucune transaction',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onSend,
                    child: const Text('Envoyer de l\'argent'),
                  ),
                ],
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
                  onTap: () => Navigator.of(context).pushNamed(
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

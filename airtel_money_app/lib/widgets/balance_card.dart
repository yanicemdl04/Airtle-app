import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/wallet_store.dart';

/// Carte flottante de profil et de solde.
///
/// Elle chevauche légèrement le header rouge et présente le nom de
/// l'utilisateur, le bouton « Mon QR », les soldes USD/CDF (masquables, lus en
/// temps réel depuis [WalletStore]) ainsi que deux actions rapides.
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.name,
    required this.phone,
    this.onMyQrTap,
    this.onCredit,
    this.onWithdraw,
  });

  final String name;
  final String phone;
  final VoidCallback? onMyQrTap;
  final VoidCallback? onCredit;
  final VoidCallback? onWithdraw;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _hidden = false;

  String _fmt(double value) {
    // Format simple façon « 1 128,5 ».
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ' ',
    );
    return '$intPart,${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 16),
          const Text(
            'Solde Airtel Money',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildBalancesRow(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.redTint,
                child: Icon(Icons.person, color: AppColors.primaryRed, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.name} | ${widget.phone}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MonQrButton(onTap: widget.onMyQrTap ?? () {}),
      ],
    );
  }

  Widget _buildBalancesRow() {
    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final store = WalletStore.instance;
        return Row(
          children: [
            Expanded(child: _balanceItem('USD', _fmt(store.balanceUsd))),
            Container(width: 1, height: 34, color: AppColors.divider),
            const SizedBox(width: 12),
            Expanded(child: _balanceItem('CDF', _fmt(store.balanceCdf))),
            IconButton(
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.primaryRed,
                size: 22,
              ),
              splashRadius: 22,
            ),
          ],
        );
      },
    );
  }

  Widget _balanceItem(String currency, String amount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          currency,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _hidden ? '••••' : amount,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _SoftActionButton(
            icon: Icons.add_circle_outline,
            label: 'Créditer son compte',
            onTap: widget.onCredit ?? () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SoftActionButton(
            icon: Icons.account_balance_outlined,
            label: "Retirer de l'argent",
            onTap: widget.onWithdraw ?? () {},
          ),
        ),
      ],
    );
  }
}

/// Bouton arrondi « Mon QR » avec une icône QR rouge.
class _MonQrButton extends StatelessWidget {
  const _MonQrButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.redTint,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded,
                  color: AppColors.primaryRed, size: 18),
              SizedBox(width: 6),
              Text(
                'Mon QR',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton « doux » à fond rouge clair et texte rouge.
class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryRed, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
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

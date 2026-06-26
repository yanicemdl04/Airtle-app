import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Header supérieur rouge de l'application.
///
/// Affiche à gauche le logo « airtel money » et à droite les actions
/// (QR code et notifications). Les coins inférieurs sont arrondis.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onQrTap,
    this.onNotificationsTap,
    this.notificationCount = 0,
    this.showMoneyBranding = true,
  });

  final VoidCallback? onQrTap;
  final VoidCallback? onNotificationsTap;
  final int notificationCount;
  final bool showMoneyBranding;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 120 + topPadding,
      padding: EdgeInsets.only(top: topPadding, left: 18, right: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryRed, AppColors.primaryRedDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _AirtelLogo(showMoney: showMoneyBranding)),
          _HeaderAction(icon: Icons.qr_code_2_rounded, onTap: onQrTap),
          _HeaderAction(
            icon: Icons.notifications_none_rounded,
            onTap: onNotificationsTap,
            badgeCount: notificationCount,
          ),
        ],
      ),
    );
  }
}

/// Logo textuel « airtel money » en blanc.
class _AirtelLogo extends StatelessWidget {
  const _AirtelLogo({this.showMoney = true});

  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (showMoney) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primaryRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'airtel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              if (showMoney)
                const Text(
                  'money',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action circulaire semi-transparent du header.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 6),
      child: Material(
        color: Colors.white24,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () {},
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

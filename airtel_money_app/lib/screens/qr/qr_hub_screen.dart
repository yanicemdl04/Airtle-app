import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../routes/app_routes.dart';
import '../../widgets/glass_container.dart';

/// Hub QR : scan et affichage du QR personnel.
class QrHubScreen extends StatelessWidget {
  const QrHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                topPadding + AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryRed, AppColors.primaryRedDark],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.md),
                  bottomRight: Radius.circular(AppSpacing.md),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Scannez ou partagez votre code de paiement',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QrActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scanner un QR',
                  subtitle: 'Payer un commerçant ou un contact',
                  gradient: const [AppColors.primaryRed, AppColors.primaryRedDark],
                  onTap: () => Navigator.pushNamed(context, AppRoutes.scanQr),
                ).animate().fadeIn().slideY(begin: 0.08, end: 0),
                const SizedBox(height: AppSpacing.sm),
                _QrActionCard(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Mon QR',
                  subtitle: 'Recevoir un paiement',
                  gradient: [AppColors.textPrimary, AppColors.iconGrey],
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myQr),
                  glass: true,
                ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.08, end: 0),
                const SizedBox(height: AppSpacing.md),
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_rounded,
                              color: AppColors.primaryRed, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Paiement sécurisé',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vos transactions QR sont chiffrées et vérifiées en temps réel par Airtel Money.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 160.ms).fadeIn(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrActionCard extends StatelessWidget {
  const _QrActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.glass = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: glass ? 0.2 : 0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.7), size: 18),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

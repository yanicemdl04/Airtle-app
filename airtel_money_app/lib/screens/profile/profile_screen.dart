import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../routes/app_routes.dart';
import '../../screens/auth_gate.dart';
import '../../services/wallet_store.dart';
import '../../widgets/airtel_card.dart';
import '../../widgets/animated_button.dart';

/// Écran profil utilisateur : infos, sécurité, appareils, déconnexion.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment quitter votre session ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    await WalletStore.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = WalletStore.instance;
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
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Profil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.notifications),
                        icon: const Icon(Icons.notifications_outlined,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Text(
                      store.ownerName.isNotEmpty
                          ? store.ownerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    store.ownerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    store.ownerPhone,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionTitle('Informations personnelles'),
                _ProfileTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Mes informations',
                  subtitle: 'Nom, téléphone, e-mail',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Vérification KYC',
                  subtitle: 'Identité vérifiée',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                _SectionTitle('Sécurité'),
                _ProfileTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Code PIN',
                  subtitle: 'Modifier votre PIN de transaction',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biométrie',
                  subtitle: 'Empreinte ou Face ID',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.devices_rounded,
                  title: 'Appareils connectés',
                  subtitle: '1 appareil actif',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                _SectionTitle('Préférences'),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Transactions, promotions, alertes',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                ),
                _ProfileTile(
                  icon: Icons.language_rounded,
                  title: 'Langue',
                  subtitle: 'Français',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedButton(
                  label: 'Déconnexion',
                  icon: Icons.logout_rounded,
                  onPressed: () => _logout(context),
                ),
                const SizedBox(height: AppSpacing.sm),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AirtelCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryRed),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

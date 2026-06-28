import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../routes/app_routes.dart';
import '../../screens/auth_gate.dart';
import '../../services/auth_service.dart';
import '../../services/toast_service.dart';
import '../../services/wallet_store.dart';
import '../../widgets/airtel_card.dart';
import '../../widgets/animated_button.dart';

/// Écran profil utilisateur : infos, sécurité, appareils, déconnexion.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ToastService.info(context, feature, message: 'Bientôt disponible');
  }

  void _showMyInfo(BuildContext context) {
    final store = WalletStore.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes informations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Nom', value: store.ownerName.isNotEmpty ? store.ownerName : '—'),
            _InfoRow(label: 'Téléphone', value: store.ownerPhone.isNotEmpty ? store.ownerPhone : '—'),
            _InfoRow(
              label: 'Compte',
              value: store.ownerPayId.isNotEmpty ? store.ownerPayId : '—',
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

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
    await AuthService.instance.logout();
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
                  subtitle: 'Nom, téléphone, compte',
                  onTap: () => _showMyInfo(context),
                ),
                _ProfileTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Vérification KYC',
                  subtitle: 'Identité vérifiée',
                  onTap: () => ToastService.success(
                    context,
                    'KYC vérifié',
                    message: 'Votre identité est déjà confirmée.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SectionTitle('Sécurité'),
                _ProfileTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Code PIN',
                  subtitle: 'Modifier votre PIN de transaction',
                  onTap: () => _comingSoon(context, 'Modification du PIN'),
                ),
                _ProfileTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biométrie',
                  subtitle: 'Empreinte ou Face ID',
                  onTap: () => _comingSoon(context, 'Authentification biométrique'),
                ),
                _ProfileTile(
                  icon: Icons.devices_rounded,
                  title: 'Appareils connectés',
                  subtitle: '1 appareil actif',
                  onTap: () => _comingSoon(context, 'Gestion des appareils'),
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
                  onTap: () => _comingSoon(context, 'Changement de langue'),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
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

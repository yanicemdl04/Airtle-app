import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../widgets/menu_item.dart';
import '../widgets/service_card.dart';
import 'auth_gate.dart';

/// Élément de fonctionnalité générique listé dans une page d'onglet.
class _Feature {
  const _Feature(this.icon, this.title, this.subtitle, {this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

/// Échafaudage commun aux onglets secondaires : header rouge + contenu.
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({
    required this.title,
    required this.headerIcon,
    required this.child,
  });

  final String title;
  final IconData headerIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 120 + topPadding,
            padding: EdgeInsets.only(top: topPadding + 24, left: 20),
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
              children: [
                Icon(headerIcon, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget _featureList(List<_Feature> features) {
  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: features.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final f = features[index];
      final tile = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, color: AppColors.primaryRed),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(f.subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      );
      if (f.onTap != null) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: f.onTap,
            borderRadius: BorderRadius.circular(14),
            child: tile,
          ),
        );
      }
      return tile;
    },
  );
}

/// Onglet « Ecran d'accueil » : services opérateur (recharge, forfaits…).
class AccueilTab extends StatelessWidget {
  const AccueilTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: "Ecran d'accueil",
      headerIcon: Icons.home_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ServiceCard(
          title: 'Services Airtel',
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: const [
              MenuItem(icon: Icons.phone_android_rounded, label: 'Recharger'),
              MenuItem(icon: Icons.sim_card_rounded, label: 'Forfaits'),
              MenuItem(icon: Icons.data_usage_rounded, label: 'Mes données'),
              MenuItem(icon: Icons.call_rounded, label: 'Appels'),
              MenuItem(icon: Icons.sms_rounded, label: 'SMS'),
              MenuItem(icon: Icons.card_giftcard_rounded, label: 'Bonus'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet « Home-Wifi ».
class HomeWifiTab extends StatelessWidget {
  const HomeWifiTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: 'Home-Wifi',
      headerIcon: Icons.wifi_rounded,
      child: _featureList(const [
        _Feature(Icons.router_rounded, 'Mon routeur',
            'État, débit et appareils connectés'),
        _Feature(Icons.speed_rounded, 'Test de débit',
            'Mesurez votre vitesse de connexion'),
        _Feature(Icons.shopping_cart_rounded, 'Acheter un forfait Wifi',
            'Forfaits internet à domicile'),
        _Feature(Icons.support_agent_rounded, 'Assistance Home-Wifi',
            'Dépannage et configuration'),
      ]),
    );
  }
}

/// Onglet « Aide ».
class AideTab extends StatelessWidget {
  const AideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: 'Aide',
      headerIcon: Icons.help_outline_rounded,
      child: _featureList(const [
        _Feature(Icons.question_answer_rounded, 'FAQ',
            'Questions fréquentes'),
        _Feature(Icons.headset_mic_rounded, 'Contacter le support',
            'Appelez le 100 (gratuit)'),
        _Feature(Icons.report_problem_rounded, 'Signaler un problème',
            'Transaction, réseau, compte'),
        _Feature(Icons.location_on_rounded, 'Agences Airtel',
            'Trouver une agence proche'),
      ]),
    );
  }
}

/// Onglet « Plus ».
class PlusTab extends StatelessWidget {
  const PlusTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      title: 'Plus',
      headerIcon: Icons.menu_rounded,
      child: _featureList([
        const _Feature(Icons.person_rounded, 'Mon profil',
            'Informations personnelles'),
        const _Feature(Icons.security_rounded, 'Sécurité',
            'PIN, biométrie, appareils'),
        const _Feature(Icons.language_rounded, 'Langue',
            'Français, English, Lingala…'),
        const _Feature(Icons.info_outline_rounded, 'À propos',
            "Version de l'application"),
        _Feature(Icons.logout_rounded, 'Déconnexion', 'Quitter la session',
            onTap: () => _logout(context)),
      ]),
    );
  }
}

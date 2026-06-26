import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Élément de menu générique : une icône dans une pastille suivie d'un libellé.
///
/// Utilisé dans les grilles « Transfert et Retrait », « Recharge et Paiements »
/// et « Services Financiers ». Le rendu reste compact et centré.
class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primaryRed,
    this.iconBackground = AppColors.redTint,
    this.onTap,
    this.iconSize = 24,
    this.labelMaxLines = 2,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback? onTap;
  final double iconSize;
  final int labelMaxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: labelMaxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.2,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

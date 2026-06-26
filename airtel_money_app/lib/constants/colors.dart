import 'package:flutter/material.dart';

/// Palette de couleurs centralisée de l'application Airtel Money.
///
/// Toutes les couleurs de la charte graphique sont définies ici afin de
/// garantir une cohérence visuelle et faciliter la maintenance.
class AppColors {
  AppColors._();

  /// Rouge principal Airtel.
  static const Color primaryRed = Color(0xFFE60012);
  static const Color primaryRedDark = Color(0xFFC1000F);

  /// Rouge très clair utilisé pour les fonds de boutons / icônes.
  static const Color redTint = Color(0xFFFDE8EA);
  static const Color redTintStrong = Color(0xFFFBD4D8);

  /// Fonds.
  static const Color scaffoldBackground = Color(0xFFF4F5F7);
  static const Color cardBackground = Colors.white;

  /// Textes.
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9A9A9A);

  /// Boutons promotionnels.
  static const Color promoBlue = Color(0xFF2D6CDF);
  static const Color promoGreen = Color(0xFF1FA463);

  /// Divers.
  static const Color divider = Color(0xFFE9E9E9);
  static const Color iconGrey = Color(0xFF5A5A5A);
  static const Color shadow = Color(0x1A000000);
  static const Color success = Color(0xFF1FA463);
  static const Color info = Color(0xFF2D6CDF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassFill = Color(0xCCFFFFFF);
}

import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Catégorie d'une notification, qui détermine son icône et sa couleur.
enum NotificationType {
  transactionSuccess,
  transactionFailed,
  promo,
  security,
  info,
}

/// Notification affichée dans le centre de notifications de l'application.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime date;
  final NotificationType type;
  bool read;

  IconData get icon {
    switch (type) {
      case NotificationType.transactionSuccess:
        return Icons.check_circle_rounded;
      case NotificationType.transactionFailed:
        return Icons.error_rounded;
      case NotificationType.promo:
        return Icons.local_offer_rounded;
      case NotificationType.security:
        return Icons.security_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.transactionSuccess:
        return AppColors.promoGreen;
      case NotificationType.transactionFailed:
        return AppColors.primaryRed;
      case NotificationType.promo:
        return AppColors.info;
      case NotificationType.security:
        return AppColors.primaryRed;
      case NotificationType.info:
        return AppColors.promoBlue;
    }
  }
}

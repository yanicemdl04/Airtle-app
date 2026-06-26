import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Notifications toast élégantes (succès, erreur, info).
class ToastService {
  ToastService._();

  static void success(BuildContext context, String title, {String? message}) {
    _show(
      context,
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    );
  }

  static void error(BuildContext context, String title, {String? message}) {
    _show(
      context,
      title: title,
      message: message,
      icon: Icons.error_outline_rounded,
      color: AppColors.primaryRed,
    );
  }

  static void info(BuildContext context, String title, {String? message}) {
    _show(
      context,
      title: title,
      message: message,
      icon: Icons.info_outline_rounded,
      color: AppColors.info,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    String? message,
    required IconData icon,
    required Color color,
  }) {
    ElegantNotification(
      autoDismiss: true,
      showProgressIndicator: false,
      position: Alignment.topCenter,
      animation: AnimationType.fromTop,
      dismissDirection: DismissDirection.up,
      width: MediaQuery.sizeOf(context).width * 0.92,
      icon: Icon(icon, color: color, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      description: Text(
        message ?? '',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      background: Colors.white,
      progressIndicatorBackground: color.withValues(alpha: 0.15),
      progressIndicatorColor: color,
    ).show(context);
  }
}

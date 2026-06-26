import 'package:flutter/material.dart';

import '../models/recipient.dart';
import '../models/transaction_record.dart';
import '../screens/my_qr_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/scan_pay_screen.dart';
import '../screens/send_money/send_money_flow.dart';
import '../screens/send_money/send_recipient_screen.dart';
import '../screens/transactions/transaction_detail_screen.dart';
import '../screens/transactions/transactions_screen.dart';

/// Routes nommées de l'application.
class AppRoutes {
  AppRoutes._();

  static const sendMoney = '/send-money';
  static const sendFlow = '/send-flow';
  static const scanQr = '/scan-qr';
  static const myQr = '/my-qr';
  static const transactions = '/transactions';
  static const transactionDetail = '/transaction-detail';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case sendMoney:
        return _slide(const SendRecipientScreen());
      case sendFlow:
        final recipient = settings.arguments as Recipient?;
        if (recipient == null) return null;
        return _slide(SendMoneyFlow(recipient: recipient));
      case scanQr:
        return _slide(const ScanPayScreen());
      case myQr:
        return _slide(const MyQrScreen());
      case transactions:
        return _slide(const TransactionsScreen());
      case transactionDetail:
        final tx = settings.arguments as TransactionRecord?;
        if (tx == null) return null;
        return _slide(TransactionDetailScreen(transaction: tx));
      case notifications:
        return _slide(const NotificationsScreen());
      case profile:
        return _slide(const ProfileScreen());
      default:
        return null;
    }
  }

  static PageRouteBuilder<T> _slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

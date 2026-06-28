import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/airtel_money_home.dart';
import '../screens/home/home_page.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/qr/qr_hub_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../services/wallet_store.dart';
import '../widgets/bottom_nav.dart';

/// Conteneur principal avec navigation bottom moderne (5 onglets).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    AirtelMoneyHomePage(),
    QrHubScreen(),
    TransactionsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final store = WalletStore.instance;
    store.refreshAll(force: true).catchError((_) => null);
    unawaited(
      store.fetchMyQr(force: true).then((_) {}, onError: (_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_record.dart';

/// Persistance locale pour affichage instantané au démarrage (cache disque).
class LocalDataStore {
  LocalDataStore._();

  static const _profileKey = 'cache_profile';
  static const _walletKey = 'cache_wallet';
  static const _transactionsKey = 'cache_transactions';
  static const _qrKey = 'cache_qr';

  static Future<void> saveProfile({
    required String id,
    required String name,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profileKey,
      jsonEncode({'id': id, 'name': name, 'phone': phone}),
    );
  }

  static Future<Map<String, String>?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      'id': map['id'] as String,
      'name': map['name'] as String,
      'phone': map['phone'] as String,
    };
  }

  static Future<void> saveWallet({
    required double balanceUsd,
    required double balanceCdf,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _walletKey,
      jsonEncode({'usd': balanceUsd, 'cdf': balanceCdf}),
    );
  }

  static Future<({double usd, double cdf})?> loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_walletKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      usd: (map['usd'] as num).toDouble(),
      cdf: (map['cdf'] as num).toDouble(),
    );
  }

  static Future<void> saveTransactions(List<TransactionRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _transactionsKey,
      jsonEncode(items.map((t) => t.toJson()).toList()),
    );
  }

  static Future<List<TransactionRecord>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transactionsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TransactionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveQr(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadQr() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_qrKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_walletKey);
    await prefs.remove(_transactionsKey);
    await prefs.remove(_qrKey);
  }
}

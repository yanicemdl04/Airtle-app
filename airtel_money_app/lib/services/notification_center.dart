import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

/// Centre de notifications de l'application (état global réactif).
///
/// Conserve la liste des notifications, expose le nombre de non-lues pour le
/// badge de la cloche, et notifie les widgets abonnés à chaque changement.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();

  /// Instance unique partagée dans toute l'application.
  static final NotificationCenter instance = NotificationCenter._();

  final List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  void push(AppNotification notification) {
    _items.insert(0, notification);
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

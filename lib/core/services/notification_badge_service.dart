import 'package:flutter/foundation.dart';

class NotificationBadgeService extends ChangeNotifier {
  static final NotificationBadgeService _instance =
  NotificationBadgeService._internal();
  factory NotificationBadgeService() => _instance;
  NotificationBadgeService._internal();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  void increment() {
    _unreadCount++;
    notifyListeners();
  }

  void reset() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners();
  }
}
import '../../models/notification_item.dart';
import '../core/feature_controller.dart';
import '../session/session_controller.dart';

/// The member's in-app notifications, newest first.
class NotificationsController extends FeatureController {
  NotificationsController(super.backend, super.report, this._session);

  final SessionController _session;

  List<NotificationItem> _items = <NotificationItem>[];
  Map<String, bool> _prefs = <String, bool>{};

  List<NotificationItem> get items => List<NotificationItem>.unmodifiable(_items.reversed);
  bool wants(String category) => _prefs[category] ?? true;

  void setWants(String category, bool on) {
    _prefs = <String, bool>{..._prefs, category: on};
    notifyListeners();
    send(() => backend.setNotificationPref(_session.uid, category, on));
  }

  int get unreadCount => _items.where((NotificationItem n) => !n.isRead).length;

  void start(String uid) {
    follow(backend.watchNotifications(uid), (List<NotificationItem> n) {
      _items = n;
      notifyListeners();
    });
    follow(backend.watchNotificationPrefs(uid), (Map<String, bool> p) {
      _prefs = p;
      notifyListeners();
    });
  }

  void markRead(String id) {
    if (_session.user != null) {
      send(() => backend.markNotificationRead(_session.uid, id));
    }
  }

  void markAllRead() {
    for (final NotificationItem n in _items.where((NotificationItem n) => !n.isRead)) {
      markRead(n.id);
    }
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _items = <NotificationItem>[];
    _prefs = <String, bool>{};
  }
}

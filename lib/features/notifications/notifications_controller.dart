import '../../models/notification_item.dart';
import '../core/feature_controller.dart';
import '../session/session_controller.dart';

/// The member's in-app notifications, newest first.
class NotificationsController extends FeatureController {
  NotificationsController(super.backend, super.report, this._session);

  final SessionController _session;

  List<NotificationItem> _items = <NotificationItem>[];

  List<NotificationItem> get items => List<NotificationItem>.unmodifiable(_items.reversed);
  int get unreadCount => _items.where((NotificationItem n) => !n.isRead).length;

  void start(String uid) {
    follow(backend.watchNotifications(uid), (List<NotificationItem> n) {
      _items = n;
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
  }
}

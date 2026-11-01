import 'dart:async';

import '../../data/backend.dart';
import '../core/feature_controller.dart';
import '../session/session_controller.dart';

/// The member's own circle, and the circle they joined as a guardian, if any.
class FamilyController extends FeatureController {
  FamilyController(super.backend, super.report, this._session);

  final SessionController _session;

  FamilyState _family = const FamilyState();
  FamilyState? _guardianView;
  StreamSubscription<FamilyState>? _guardianSub;
  String? _linked;

  FamilyState get family => _family;
  FamilyState? get guardianView => _guardianView;

  void start(String uid) {
    follow(backend.watchFamily(uid), (FamilyState f) {
      _family = f;
      notifyListeners();
    }, silent: true);
  }

  /// Follows the circle this account belongs to as a guardian.
  void link(String? member) {
    if (member == _linked) return;
    _linked = member;
    unawaited(_guardianSub?.cancel());
    _guardianSub = null;
    _guardianView = null;
    if (member != null) {
      _guardianSub = backend.watchFamily(member).listen((FamilyState f) {
        _guardianView = f;
        notifyListeners();
      }, onError: report);
    }
  }

  Future<String> createInvite() => backend.createFamilyInvite();
  Future<void> join(String code, String name) => backend.joinFamily(code, name);
  Future<void> removeGuardian(String guardian) => backend.removeGuardian(guardian);
  Future<void> share(String profileId) => backend.shareWithFamily(profileId);

  void giveOpinion(String profileId, String opinion) {
    final String? member = _session.account.familyOf;
    if (member != null) {
      send(() => backend.giveFamilyOpinion(member, profileId, opinion));
    }
  }

  @override
  Future<void> stop() async {
    await super.stop();
    link(null);
    _family = const FamilyState();
  }
}

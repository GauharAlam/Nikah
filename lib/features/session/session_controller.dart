import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend.dart';
import '../core/feature_controller.dart';

/// Where a signed-in member is in the app.
enum AuthStage { guest, onboarding, active }

/// Auth user, server-owned account state and limits.
class SessionController extends FeatureController {
  SessionController(super.backend, super.report, this._prefs);

  final SharedPreferences _prefs;

  AuthUser? _user;
  AccountState _account = const AccountState();
  AppLimits _limits = const AppLimits();
  AuthStage _stage = AuthStage.guest;
  bool _restoring = true;

  /// Runs when the account says this member belongs to a family circle.
  void Function(String? member)? onFamilyLink;

  AuthUser? get user => _user;
  String get uid => _user?.uid ?? '';
  bool get isRestoring => _restoring;
  bool get isSignedIn => _stage != AuthStage.guest;
  bool get isActive => _stage == AuthStage.active;
  bool get isReviewer => _user?.isReviewer ?? false;
  bool get hasApprovedClaim => _user?.isApproved ?? false;
  AuthStage get stage => _stage;
  AccountState get account => _account;
  AppLimits get limits => _limits;
  ReviewStage get reviewStage => _account.stage;
  bool get isPremium => _account.isPremium;

  bool get pledgeAccepted => _prefs.getBool('bk_pledge_$uid') ?? false;

  void acceptPledge() {
    unawaited(_prefs.setBool('bk_pledge_$uid', true));
    notifyListeners();
  }

  /// A token refresh for the same member. Returns true when it brought approval.
  bool refresh(AuthUser user) {
    final bool gained = user.isApproved && !hasApprovedClaim;
    _user = user;
    notifyListeners();
    return gained;
  }

  void begin(AuthUser user) {
    _user = user;
    _stage = AuthStage.onboarding;
  }

  void signedOut() {
    _user = null;
    _stage = AuthStage.guest;
    _restoring = false;
    notifyListeners();
  }

  void start(String uid) {
    follow(backend.watchAccount(uid), _onAccount);
    follow(backend.watchLimits(), (AppLimits l) {
      _limits = l;
      notifyListeners();
    });
  }

  void restored() {
    _restoring = false;
    notifyListeners();
  }

  void _onAccount(AccountState account) {
    final ReviewStage before = _account.stage;
    _account = account;
    onFamilyLink?.call(account.familyOf);
    final bool approved = account.stage == ReviewStage.approved;
    _stage = approved ? AuthStage.active : AuthStage.onboarding;
    // The approved claim is set just after the stage changes.
    if (approved && before != ReviewStage.approved) send(backend.refreshClaims);
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _account = const AccountState();
  }
}

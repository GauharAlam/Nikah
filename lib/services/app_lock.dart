import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Optional lock on opening the app. Holds no secret: it only asks the phone
/// to confirm its owner, using the phone's own lock.
class AppLock {
  AppLock._();

  static const String _key = 'bk_app_lock';
  static final LocalAuthentication _auth = LocalAuthentication();

  static bool enabled(SharedPreferences prefs) => prefs.getBool(_key) ?? false;

  static Future<bool> confirm() async {
    try {
      return await _auth.authenticate(localizedReason: 'Unlock the app');
    } on Object {
      return false;
    }
  }

  /// Turning it on needs a working phone lock, so nobody is locked out.
  static Future<bool> setEnabled(SharedPreferences prefs, bool on) async {
    if (on && !await _auth.isDeviceSupported()) return false;
    if (on && !await confirm()) return false;
    await prefs.setBool(_key, on);
    return true;
  }
}

/// Covers the app when lock is on, at launch and on return from the background.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.prefs, required this.child, this.confirm = AppLock.confirm});

  final SharedPreferences prefs;
  final Widget child;
  final Future<bool> Function() confirm;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = AppLock.enabled(widget.prefs);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) unawaited(_unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && AppLock.enabled(widget.prefs)) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      unawaited(_unlock());
    }
  }

  Future<void> _unlock() async {
    if (await widget.confirm() && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              key: const Key('app_locked'),
              color: Colors.black,
              child: Center(
                child: FilledButton.icon(
                  key: const Key('app_unlock'),
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(tr('Unlock')),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

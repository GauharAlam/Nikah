import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences that belong to the device, not the account.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  static const String _kArabic = 'bk_show_arabic';

  final SharedPreferences _prefs;

  bool get showArabic => _prefs.getBool(_kArabic) ?? true;

  void setShowArabic(bool value) {
    unawaited(_prefs.setBool(_kArabic, value));
    notifyListeners();
  }
}

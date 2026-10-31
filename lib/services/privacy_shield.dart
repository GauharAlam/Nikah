import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Best-effort screenshot / screen-recording protection for member photos and
/// biodata.
///
/// Android: `FLAG_SECURE` on the activity window (`MainActivity.kt`).
/// iOS: the secure-text-entry layer trick (`AppDelegate.swift`, not yet compiled
/// or run on a device) — iOS exposes
/// no true FLAG_SECURE equivalent, so this is best-effort and does not defeat
/// a physical camera on either platform.
///
/// Reference-counted so several screens can hold the shield at once.
/// Silently no-ops on desktop and in widget tests where the native
/// implementation is not available.
class PrivacyShield {
  PrivacyShield._();

  static const MethodChannel _channel =
      MethodChannel('com.barkat.nikah/privacy_shield');
  static int _holders = 0;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> enable() async {
    _holders++;
    if (_holders > 1 || !_supported) return;
    try {
      await _channel.invokeMethod<bool>('enable');
    } catch (_) {
      // No native implementation (tests / desktop) — ignore.
    }
  }

  static Future<void> disable() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders > 0 || !_supported) return;
    try {
      await _channel.invokeMethod<bool>('disable');
    } catch (_) {
      // No native implementation (tests / desktop) — ignore.
    }
  }
}

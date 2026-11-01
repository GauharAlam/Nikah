import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/backend.dart';

/// Base for feature state managers. Owns stream subscriptions, so a controller
/// can stop cleanly when the member signs out.
abstract class FeatureController extends ChangeNotifier {
  FeatureController(this.backend, this.report);

  final Backend backend;

  /// Sends a failure to the app-wide error channel.
  final void Function(Object error) report;

  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  bool _disposed = false;

  /// Follows [stream] until [stop]. [silent] streams may fail while a member
  /// has no such document, so their errors are dropped.
  @protected
  void follow<T>(Stream<T> stream, void Function(T) onData, {bool silent = false}) {
    _subs.add(stream.listen(onData, onError: silent ? (Object _) {} : report));
  }

  /// Runs a server call; failures surface through [report].
  @protected
  void send(Future<void> Function() call) {
    unawaited(() async {
      try {
        await call();
      } on Object catch (e) {
        report(e);
      }
    }());
  }

  /// Cancels subscriptions and forgets this member's state.
  @mustCallSuper
  Future<void> stop() async {
    for (final StreamSubscription<dynamic> s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
